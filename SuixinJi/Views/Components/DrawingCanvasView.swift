import SwiftUI
import PencilKit

/// 手写涂鸦 (evolution). A PencilKit canvas with the native tool picker. On 完成 it
/// flattens the strokes to a white-background `UIImage`, which the editor attaches
/// as a normal photo — so a drawing rides the existing image pipeline (display,
/// iCloud sync, backup, export, delete) with no new storage/model surface.
/// Finger drawing is enabled (`.anyInput`), so it works without an Apple Pencil.
struct DrawingCanvasView: View {
    /// The rendered drawing, or nil if the user cancelled / drew nothing.
    var onFinish: (UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()

    var body: some View {
        NavigationStack {
            DrawingCanvas(canvas: canvas)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("涂鸦")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { finish(nil) }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { finish(image()) }
                            .fontWeight(.semibold)
                    }
                }
        }
    }

    private func finish(_ image: UIImage?) {
        onFinish(image)
        dismiss()
    }

    /// Flatten the drawing onto white. nil when nothing was drawn.
    private func image() -> UIImage? {
        let drawing = canvas.drawing
        guard !drawing.bounds.isNull, !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24) // a little margin
        let format = UIGraphicsImageRendererFormat.default()
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(bounds)
            drawing.image(from: bounds, scale: format.scale).draw(in: bounds)
        }
    }
}

/// UIKit bridge for `PKCanvasView` + the native `PKToolPicker`. The picker is set
/// up on the next runloop tick so the canvas is already in a window (becoming
/// first responder before that silently fails to show the picker).
private struct DrawingCanvas: UIViewRepresentable {
    let canvas: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)
        canvas.backgroundColor = .systemBackground
        let picker = PKToolPicker()
        context.coordinator.picker = picker // retain, or it deallocates
        DispatchQueue.main.async {
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var picker: PKToolPicker?
    }
}
