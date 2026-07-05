import UIKit
import Social
import UniformTypeIdentifiers

/// Share Extension entry point. Presents the system compose sheet (pre-filled with
/// shared text/URL); on 发布 it stashes the text + any images into the App Group
/// `ShareInbox`. The main app imports them into new diary entries on next launch.
/// The extension never touches SwiftData — it's a dumb writer.
class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool { true }

    override func presentationAnimationDidFinish() {
        placeholder = "写点什么，一并存进随心记…"
    }

    override func didSelectPost() {
        let text = contentText ?? ""
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []

        let group = DispatchGroup()
        let lock = NSLock()
        var images: [Data] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            group.enter()
            provider.loadDataRepresentation(for: .image) { data, _ in
                if let data {
                    lock.lock(); images.append(data); lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            ShareInbox.write(text: text, imageDatas: images)
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! { [] }
}
