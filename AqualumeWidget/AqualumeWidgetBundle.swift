import WidgetKit
import SwiftUI

@main
struct AqualumeWidgetBundle: WidgetBundle {
    var body: some Widget {
        AqualumeProgressWidget()
        HydrationLiveActivity()
    }
}
