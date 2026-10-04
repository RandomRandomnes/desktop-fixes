import QtQuick
import qs.modules.common

// Card that navigates to another page/sub-page (Windows 11 "›" rows).
WCard {
    id: root
    property string page: WState.page
    property string sub: ""
    property var action: null          // optional: run this instead of navigating

    clickable: true
    chevron: true
    onClicked: {
        if (root.action) root.action();
        else WState.go(root.page, root.sub);
    }
}
