import WidgetKit
import SwiftUI

@main
struct KeepersTodayInfoWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeepersTodayInfoWidget()
        KeepersTodoWidget()
        KeepersCropTimerWidget()
    }
}