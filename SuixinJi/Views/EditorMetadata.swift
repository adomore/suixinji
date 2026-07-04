import SwiftUI

/// The metadata strip in the editor: 心情 (F7) · 天气 (F14) · 位置 (F14) · 标签 (F14).
/// Kept calm — small SF Symbol chips that reveal a picker; selected values show
/// inline. Nothing here is required to save.
struct EditorMetadataView: View {
    @Binding var mood: String?
    @Binding var weather: String?
    @Binding var weatherText: String?
    @Binding var tags: [String]
    @Binding var locationName: String?
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @StateObject private var location = LocationProvider()
    @StateObject private var weatherProvider = WeatherProvider()
    @State private var showMood = false
    @State private var showWeather = false
    @State private var showWeatherOptions = false
    @State private var showTagInput = false
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(system: "face.smiling", value: mood, placeholder: "心情") { showMood = true }
                    weatherChip
                    locationChip
                    tagChip
                }
            }
            if !tags.isEmpty { tagRow }
        }
        .sheet(isPresented: $showMood) {
            EmojiGridSheet(title: "选择心情", options: DiaryCatalog.moods, selection: $mood)
        }
        .sheet(isPresented: $showWeather) {
            EmojiGridSheet(title: "选择天气", options: DiaryCatalog.weathers, selection: $weather)
        }
        .confirmationDialog("天气", isPresented: $showWeatherOptions, titleVisibility: .visible) {
            Button("自动获取（WeatherKit）") { fetchWeather() }
            Button("手动选择") { weatherText = nil; showWeather = true }
            if weather != nil {
                Button("清除", role: .destructive) { weather = nil; weatherText = nil }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("添加标签", isPresented: $showTagInput) {
            TextField("标签", text: $newTag)
            Button("添加") { addTag() }
            Button("取消", role: .cancel) { newTag = "" }
        }
        .alert("天气", isPresented: .init(
            get: { weatherProvider.errorMessage != nil },
            set: { if !$0 { weatherProvider.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: { Text(weatherProvider.errorMessage ?? "") }
    }

    // Weather chip: shows emoji + "晴 26°" text, or a spinner while fetching.
    private var weatherChip: some View {
        Button { showWeatherOptions = true } label: {
            HStack(spacing: 5) {
                if weatherProvider.isLoading {
                    ProgressView().controlSize(.mini)
                } else if let weather {
                    Text(weather).font(.system(size: 15))
                } else {
                    Image(systemName: "cloud.sun").font(.system(size: 14))
                }
                Text(weatherText ?? (weather == nil ? "天气" : "")).font(.aux13).lineLimit(1)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Color.cardBackground, in: Capsule())
            .foregroundStyle(weather == nil ? Color.secondary : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func fetchWeather() {
        Task {
            var lat = latitude, lon = longitude
            // Need coordinates — grab the current location if we don't have any.
            if lat == nil || lon == nil {
                if let place = await location.currentPlace() {
                    lat = place.latitude; lon = place.longitude
                    latitude = place.latitude; longitude = place.longitude
                    if locationName == nil { locationName = place.name }
                }
            }
            guard let lat, let lon else { return }
            if let reading = await weatherProvider.fetch(latitude: lat, longitude: lon) {
                weather = reading.emoji
                weatherText = reading.text
            }
        }
    }

    // Generic emoji chip (mood / weather): shows the emoji once chosen.
    private func chip(system: String, value: String?, placeholder: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let value { Text(value).font(.system(size: 15)) }
                else { Image(systemName: system).font(.system(size: 14)) }
                Text(value == nil ? placeholder : "").font(.aux13)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Color.cardBackground, in: Capsule())
            .foregroundStyle(value == nil ? Color.secondary : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var locationChip: some View {
        Button {
            if locationName == nil { fetchLocation() } else { clearLocation() }
        } label: {
            HStack(spacing: 5) {
                if location.isResolving {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: locationName == nil ? "location" : "location.fill")
                        .font(.system(size: 14))
                }
                Text(locationName ?? "位置").font(.aux13).lineLimit(1)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Color.cardBackground, in: Capsule())
            .foregroundStyle(locationName == nil ? Color.secondary : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var tagChip: some View {
        Button { showTagInput = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "tag").font(.system(size: 14))
                Text("标签").font(.aux13)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Color.cardBackground, in: Capsule())
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)").font(.aux13)
                        Button { tags.removeAll { $0 == tag } } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.brand.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.brand)
                }
            }
        }
    }

    private func addTag() {
        let t = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        newTag = ""
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
    }

    private func fetchLocation() {
        Task {
            if let place = await location.currentPlace() {
                locationName = place.name
                latitude = place.latitude
                longitude = place.longitude
            }
        }
    }

    private func clearLocation() {
        locationName = nil; latitude = nil; longitude = nil
    }
}

/// Reusable emoji picker sheet. Tapping an emoji sets the binding and dismisses;
/// tapping the current one clears it.
struct EmojiGridSheet: View {
    let title: String
    let options: [String]
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(options, id: \.self) { emoji in
                    Button {
                        selection = (selection == emoji) ? nil : emoji
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 34))
                            .frame(width: 60, height: 60)
                            .background(
                                selection == emoji ? Color.brand.opacity(0.15) : Color.cardBackground,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
                if selection != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("清除") { selection = nil; dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
