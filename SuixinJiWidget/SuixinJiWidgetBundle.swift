import WidgetKit
import SwiftUI

@main
struct SuixinJiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        MoodCheckInWidget()
        DailyQuoteWidget()
        WritingLiveActivity()
    }
}
