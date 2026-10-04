import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Io

// Stock-style resources popup (as before 2026-10-03), used when Settings › Extras › resource graphs is off.
StyledPopup {
   id: root

   function formatKB(kb) {
       return (kb / (1024 * 1024)).toFixed(1) + " GB"
   }

   Row {
       spacing: 5

       Column {
           spacing: 5

           ResourceCard {
               label: "RAM"
               iconText: "memory"
               iconShape: MaterialShape.Shape.Clover4Leaf
               value: ResourceUsage.memoryUsed / ResourceUsage.memoryTotal
               sublabel: root.formatKB(ResourceUsage.memoryUsed) + " / " + root.formatKB(ResourceUsage.memoryTotal)
           }

           ResourceCard {
               label: "CPU"
               iconText: "planner_review"
               iconShape: MaterialShape.Shape.Gem
               value: ResourceUsage.cpuUsage
               sublabel: `${Math.round(ResourceUsage.cpuTemp)}°C`
               sublabelColor: ResourceUsage.cpuTemp > 80 ? Appearance.colors.colError
                   : ResourceUsage.cpuTemp > 60 ? Appearance.m3colors.m3tertiary
                   : Appearance.colors.colOnLayer1
           }
       }

       Column {
           spacing: 5

           ResourceCard {
               label: "Swap"
               iconText: "swap_horiz"
               iconShape: MaterialShape.Shape.Bun
               value: ResourceUsage.swapUsedPercentage
               sublabel: root.formatKB(ResourceUsage.swapUsed) + " / " + root.formatKB(ResourceUsage.swapTotal)
           }

           ResourceCard {
               label: "Disk"
               iconText: "hard_drive"
               iconShape: MaterialShape.Shape.Circle
               value: ResourceUsage.diskUsedPercentage
               sublabel: root.formatKB(ResourceUsage.diskUsed) + " / " + root.formatKB(ResourceUsage.diskTotal)
           }
       }

       Column {
           spacing: 5
           visible: Config.options.bar.resources.alwaysShowGpu && ResourceUsage.gpuAvailable

           ResourceCard {
               label: "GPU"
               iconText: "developer_board"
               iconShape: MaterialShape.Shape.Circle
               value: ResourceUsage.gpuUsage
               sublabel: `${ResourceUsage.gpuVramUsedGB.toFixed(1)} / ${ResourceUsage.gpuVramTotalGB.toFixed(1)} GB`
               sublabelColor: ResourceUsage.gpuTemperature > 80 ? Appearance.colors.colError
                   : ResourceUsage.gpuTemperature > 60 ? Appearance.m3colors.m3tertiary
                   : Appearance.colors.colOnLayer1
           }

           ResourceCard {
               visible: ResourceUsage.gpuPowerAvailable
               label: "GPU Power"
               iconText: "bolt"
               iconShape: MaterialShape.Shape.Circle
               value: ResourceUsage.gpuPowerUsage
               sublabel: ResourceUsage.gpuPowerCapW > 0
                   ? `${ResourceUsage.gpuPowerDrawW.toFixed(0)} / ${ResourceUsage.gpuPowerCapW.toFixed(0)} W`
                   : `${ResourceUsage.gpuPowerDrawW.toFixed(0)} W`
           }
       }
   }
}

