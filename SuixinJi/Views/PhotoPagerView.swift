import SwiftUI

/// Full-image horizontal pager (UI Brief §4 ③ "点击进入横滑大图，系统 pager 风格").
struct PhotoPagerView: View {
    let fileNames: [String]
    var startIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(fileNames: [String], startIndex: Int) {
        self.fileNames = fileNames
        self.startIndex = startIndex
        _selection = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(fileNames.enumerated()), id: \.offset) { idx, name in
                    Group {
                        if let img = FileStore.shared.loadImage(name) {
                            Image(uiImage: img).resizable().scaledToFit()
                        } else {
                            Color(uiColor: .darkGray)
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: fileNames.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 12)
            .padding(.leading, 16)
        }
    }
}
