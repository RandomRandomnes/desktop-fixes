import QtQuick

/**
 * Runs the local Claude Code CLI (`claude -p`, stream-json) instead of calling an HTTP API.
 * Same setup as a terminal session started in ~: same memory/CLAUDE.md, default model, "auto"
 * permission mode (safe actions run, anything that would need an approval prompt is refused).
 * Follow-up messages resume the same Claude Code session; when the chat was cleared, edited,
 * regenerated or loaded from a save, a new session starts with the earlier chat as context.
 */
ApiStrategy {
    id: strategy
    readonly property string claudeBin: "$HOME/.local/bin/claude"
    readonly property string sidebarPrompt: "You are running inside the AI chat panel of the user's Quickshell (illogical-impulse) sidebar on their Hyprland desktop, not in a terminal. The panel renders Markdown; keep replies reasonably short since the panel is narrow. Tools that wait for a reply in the terminal (multiple-choice questions, plan approval) do not work here, so ask in plain text instead. Actions that would need a permission prompt are refused automatically; if one is needed, say so and suggest continuing in a terminal with `claude --resume`."

    // Conversation state, kept across requests (reset() only clears per-request state)
    property string sessionId: ""
    property int coveredCount: 0    // chat messages (user + assistant) the session already contains
    property int pendingCount: 0
    property string pendingPrompt: ""
    property bool pendingResume: false
    property string pendingSessionId: ""

    // Per-request state
    property bool isThinking: false
    property bool gotResult: false
    property var blockTypes: ({})

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function buildEndpoint(model) { return ""; }
    function buildAuthorizationHeader(apiKeyEnvVarName) { return ""; }

    function buildRequestData(model, messages, systemPrompt, temperature, tools, filePath) {
        const last = messages[messages.length - 1];
        let text = last?.rawContent ?? "";
        if (filePath && filePath.length > 0) text += `\n\n[Attached file: ${filePath}]`;

        const canResume = sessionId.length > 0 && messages.length === coveredCount + 1;
        pendingResume = canResume;
        pendingSessionId = canResume ? sessionId : "";
        pendingCount = messages.length;
        if (canResume || messages.length <= 1) {
            pendingPrompt = text;
        } else {
            const history = messages.slice(0, -1).map(m =>
                `${m.role === "user" ? "User" : "Assistant"}: ${m.rawContent}`).join("\n\n");
            pendingPrompt = `Earlier messages in this sidebar chat, for context:\n\n${history}\n\n---\n\nNew message:\n${text}`;
        }
        if (!canResume) sessionId = "";
        return {};
    }

    function finalizeScriptContent(scriptContent) {
        const args = ["-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages",
                      "--permission-mode", "auto", "--append-system-prompt", sidebarPrompt];
        if (pendingResume) args.push("--resume", pendingSessionId);
        else args.push("--name", "Sidebar chat");
        return "#!/usr/bin/env bash\n"
            + 'cd "$HOME" || exit 1\n'
            + `printf '%s' ${shellQuote(pendingPrompt)} | "${claudeBin}" ${args.map(shellQuote).join(" ")} 2>&1\n`;
    }

    function append(message, text) {
        message.rawContent += text;
        message.content += text;
    }

    function endThinking(message) {
        if (isThinking) {
            isThinking = false;
            append(message, "\n\n</think>\n\n");
        }
    }

    function short(s, n) {
        s = String(s ?? "").replace(/`/g, "'").replace(/\s+/g, " ").trim();
        return s.length > n ? s.slice(0, n - 1) + "…" : s;
    }

    function describeTool(name, input) {
        input = input || {};
        switch (name) {
        case "Bash": return `Ran \`${short(input.description || input.command, 90)}\``;
        case "Read": return `Read \`${short(input.file_path, 90)}\``;
        case "Edit": return `Edited \`${short(input.file_path, 90)}\``;
        case "Write": return `Wrote \`${short(input.file_path, 90)}\``;
        case "Grep": return `Searched for \`${short(input.pattern, 60)}\``;
        case "Glob": return `Listed \`${short(input.pattern, 60)}\``;
        case "WebSearch": return `Searched the web for \`${short(input.query, 70)}\``;
        case "WebFetch": return `Fetched \`${short(input.url, 80)}\``;
        case "Agent": return `Started an agent: ${short(input.description, 70)}`;
        default: return `Used ${name}`;
        }
    }

    function parseResponseLine(line, message) {
        let d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            append(message, line + "\n"); // stderr or non-JSON output, e.g. "command not found"
            return {};
        }

        if (d.type === "system" && d.subtype === "init") {
            pendingSessionId = d.session_id ?? pendingSessionId;
            return {};
        }

        if (d.type === "stream_event") {
            const e = d.event;
            if (e.type === "content_block_start") {
                blockTypes[e.index] = e.content_block?.type;
                if (e.content_block?.type === "text" && message.rawContent.length > 0 && !message.rawContent.endsWith("\n\n"))
                    append(message, "\n\n");
            } else if (e.type === "content_block_delta") {
                if (e.delta?.type === "text_delta") {
                    endThinking(message);
                    append(message, e.delta.text);
                } else if (e.delta?.type === "thinking_delta") {
                    if (!isThinking) {
                        isThinking = true;
                        append(message, "\n\n<think>\n\n");
                    }
                    append(message, e.delta.thinking);
                }
            }
            return {};
        }

        // Whole assistant messages repeat the streamed text; only tool calls are taken from them.
        if (d.type === "assistant") {
            for (const block of (d.message?.content ?? [])) {
                if (block.type !== "tool_use") continue;
                endThinking(message);
                const sep = message.rawContent.length === 0 || message.rawContent.endsWith("\n\n") ? "" : "\n\n";
                append(message, `${sep}> ${describeTool(block.name, block.input)}\n\n`);
            }
            return {};
        }

        if (d.type === "user") {
            for (const block of (d.message?.content ?? [])) {
                if (block.type === "tool_result" && block.is_error) {
                    const content = Array.isArray(block.content) ? block.content.map(c => c.text ?? "").join(" ") : block.content;
                    append(message, `> ↳ *${short(content, 140)}*\n\n`);
                }
            }
            return {};
        }

        if (d.type === "result") {
            gotResult = true;
            endThinking(message);
            if (d.is_error) {
                append(message, `\n\n**Error**: ${d.result ?? d.subtype}`);
            } else {
                sessionId = d.session_id ?? pendingSessionId;
                coveredCount = pendingCount + 1;
            }
            const denied = d.permission_denials?.length ?? 0;
            if (denied > 0)
                append(message, `\n\n*${denied} action(s) needed approval and were skipped. Continue in a terminal with* \`claude --resume ${d.session_id}\``);
            const u = d.usage ?? {};
            const input = (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0);
            return {
                finished: true,
                tokenUsage: { input: input, output: u.output_tokens ?? -1, total: input + (u.output_tokens ?? 0) }
            };
        }
        return {};
    }

    function onRequestFinished(message) {
        if (!gotResult && message.rawContent.length === 0)
            append(message, "**Error**: Claude Code exited without a reply.");
        return {};
    }

    function reset() {
        isThinking = false;
        gotResult = false;
        blockTypes = ({});
    }
}
