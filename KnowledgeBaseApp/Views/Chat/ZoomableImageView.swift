import SwiftUI
import UIKit

/// Pinch/double-tap zoom for fullscreen image preview (chat + Structured UI).
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var onZoomScaleChange: ((_ current: CGFloat, _ minimum: CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(image: image, onZoomScaleChange: onZoomScaleChange)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        DispatchQueue.main.async {
            context.coordinator.layoutImage(in: scrollView)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onZoomScaleChange = onZoomScaleChange
        context.coordinator.imageView?.image = image
        if scrollView.bounds.width > 0, scrollView.bounds.height > 0 {
            context.coordinator.layoutImage(in: scrollView)
        }
    }

    static func dismantleUIView(_ scrollView: UIScrollView, coordinator: Coordinator) {
        coordinator.scrollView = nil
        coordinator.imageView = nil
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        private let image: UIImage
        var onZoomScaleChange: ((_ current: CGFloat, _ minimum: CGFloat) -> Void)?

        init(image: UIImage, onZoomScaleChange: ((_ current: CGFloat, _ minimum: CGFloat) -> Void)?) {
            self.image = image
            self.onZoomScaleChange = onZoomScaleChange
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
            onZoomScaleChange?(scrollView.zoomScale, scrollView.minimumZoomScale)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }
            let point = recognizer.location(in: imageView)
            let zoomRect = zoomRect(for: scrollView, scale: min(scrollView.maximumZoomScale, 2.5), center: point)
            scrollView.zoom(to: zoomRect, animated: true)
        }

        func layoutImage(in scrollView: UIScrollView) {
            guard let imageView else { return }
            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size
            scrollView.zoomScale = scrollView.minimumZoomScale
            fitImage(in: scrollView)
        }

        private func fitImage(in scrollView: UIScrollView) {
            guard let imageView else { return }
            let bounds = scrollView.bounds
            guard bounds.width > 0, bounds.height > 0, image.size.width > 0, image.size.height > 0 else { return }
            let widthScale = bounds.width / image.size.width
            let heightScale = bounds.height / image.size.height
            let scale = min(widthScale, heightScale)
            scrollView.minimumZoomScale = scale
            scrollView.zoomScale = scale
            imageView.frame = CGRect(
                x: 0,
                y: 0,
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            scrollView.contentSize = imageView.frame.size
            centerImage(in: scrollView)
            onZoomScaleChange?(scrollView.zoomScale, scrollView.minimumZoomScale)
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }

        private func zoomRect(for scrollView: UIScrollView, scale: CGFloat, center: CGPoint) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale
            )
            let origin = CGPoint(
                x: center.x - size.width * 0.5,
                y: center.y - size.height * 0.5
            )
            return CGRect(origin: origin, size: size)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
