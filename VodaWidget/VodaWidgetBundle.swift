import WidgetKit
import SwiftUI

@main
struct VodaWidgetBundle: WidgetBundle {
    var body: some Widget {
        VodaProgressWidget()
        HydrationLiveActivity()
    }
}
