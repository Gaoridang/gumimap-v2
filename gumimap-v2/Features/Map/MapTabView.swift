import MapKit
import SwiftData
import SwiftUI

struct MapTabView: View {
    @Query(sort: \SavedPlace.registeredAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @Environment(TabRouter.self) private var router

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: SearchRegion.gumiCenter,
            latitudinalMeters: 12_000,
            longitudinalMeters: 12_000
        )
    )

    var body: some View {
        Map(position: $position) {
            ForEach(savedPlaces, id: \.id) { savedPlace in
                if let listKind = savedPlace.listSubTab {
                    Annotation(savedPlace.name, coordinate: savedPlace.asPlace.coordinate) {
                        Button {
                            router.openSavedPlaceDetail(id: savedPlace.id)
                        } label: {
                            SavedPlaceMapPin(listKind: listKind, category: savedPlace.category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    MapTabView()
        .environment(TabRouter())
        .modelContainer(for: SavedPlace.self, inMemory: true)
}