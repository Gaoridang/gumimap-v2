import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedPlace.self, PlacePhoto.self], inMemory: true)
}