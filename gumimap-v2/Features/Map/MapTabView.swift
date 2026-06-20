import MapKit
import SwiftUI

struct MapTabView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: SearchRegion.gumiCenter,
            latitudinalMeters: 12_000,
            longitudinalMeters: 12_000
        )
    )

    var body: some View {
        Map(position: $position)
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    MapTabView()
}