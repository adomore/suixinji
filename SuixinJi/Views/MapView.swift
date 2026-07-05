import SwiftUI
import SwiftData
import MapKit

/// 地图足迹 (evolution). Plots every located diary entry (F14 lat/long) as a pin,
/// clustered by place; tapping a pin lists that spot's entries → detail. Presented
/// as a sheet from Home, same pattern as 统计 / 日历.
struct MapView: View {
    @Query(sort: [SortDescriptor(\DiaryEntry.createdAt, order: .reverse)])
    private var entries: [DiaryEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: MapFootprints.Place?

    private var places: [MapFootprints.Place] { MapFootprints.places(from: entries) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if places.isEmpty {
                    emptyState
                } else {
                    map
                    if let place = selected {
                        placeCard(place)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("足迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .navigationDestination(for: DiaryEntry.self) { DetailView(entry: $0) }
        }
    }

    // MARK: Map

    private var map: some View {
        Map(position: $camera) {
            ForEach(places) { place in
                Annotation(place.name ?? "未命名地点", coordinate: place.coordinate) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selected = (selected?.id == place.id) ? nil : place
                        }
                    } label: {
                        pin(place)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapControls { MapUserLocationButton(); MapCompass() }
        .ignoresSafeArea(edges: .bottom)
    }

    private func pin(_ place: MapFootprints.Place) -> some View {
        let isSelected = selected?.id == place.id
        return ZStack {
            Circle()
                .fill(Color.accentColor)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            if place.count > 1 {
                Text("\(place.count)")
                    .scaledFont(13, weight: .bold)
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "book.closed.fill")
                    .scaledFont(12, weight: .semibold)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
    }

    // MARK: Selected-place card (entries → detail)

    private func placeCard(_ place: MapFootprints.Place) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name ?? "未命名地点").scaledFont(17, weight: .semibold)
                    Text("\(place.count) 篇日记").scaledFont(13).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { selected = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(22).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(place.entries) { entry in
                        NavigationLink(value: entry) { entryRow(entry) }
                            .buttonStyle(.plain)
                        if entry.id != place.entries.last?.id { Divider() }
                    }
                }
            }
            .frame(maxHeight: 240)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func entryRow(_ entry: DiaryEntry) -> some View {
        HStack(spacing: 10) {
            if let mood = entry.mood { Text(mood).scaledFont(18) }
            VStack(alignment: .leading, spacing: 3) {
                Text(DiaryDateFormat.shortChinese(entry.diaryDate))
                    .scaledFont(13).foregroundStyle(.secondary)
                Text(entry.text.isEmpty ? "（无文字）" : entry.text)
                    .scaledFont(15).lineLimit(1)
                    .foregroundStyle(entry.text.isEmpty ? .secondary : .primary)
            }
            Spacer(minLength: 4)
            if !entry.imageFileNames.isEmpty {
                Image(systemName: "photo").scaledFont(12).foregroundStyle(.secondary)
            }
            if entry.hasAudio {
                Image(systemName: "waveform").scaledFont(12).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").scaledFont(12).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .scaledFont(44, weight: .light)
                .foregroundStyle(.secondary)
            Text("还没有带位置的日记")
                .scaledFont(17, weight: .semibold)
            Text("写日记时点「位置」记录地点，足迹就会出现在这里。")
                .scaledFont(14)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groupedBackground.ignoresSafeArea())
    }
}

#Preview {
    MapView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
        .environmentObject(ThemeManager())
        .tint(.brand)
}
