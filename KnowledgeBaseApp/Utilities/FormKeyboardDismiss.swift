import SwiftUI
#if canImport(UIKit)
import UIKit

/// Installs a background tap dismiss on the enclosing Form/`UITableView` /
/// `UIScrollView` without stealing taps from controls and text fields.
private final class FormKeyboardDismissInstallerView: UIView, UIGestureRecognizerDelegate {
    private let tap = UITapGestureRecognizer()
    private weak var attachedScroll: UIScrollView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        tap.addTarget(self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        installIfNeeded()
    }

    private func installIfNeeded() {
        guard window != nil else { return }
        guard let scroll = nearestScrollView() else { return }
        if attachedScroll === scroll { return }
        detach()
        scroll.keyboardDismissMode = .none
        scroll.addGestureRecognizer(tap)
        attachedScroll = scroll
    }

    private func detach() {
        if let attachedScroll, let recognizers = attachedScroll.gestureRecognizers, recognizers.contains(tap) {
            attachedScroll.removeGestureRecognizer(tap)
        }
        attachedScroll = nil
    }

    deinit {
        detach()
    }

    private func nearestScrollView() -> UIScrollView? {
        var view: UIView? = superview
        while let current = view {
            if let scroll = current as? UIScrollView {
                return scroll
            }
            view = current.superview
        }
        return nil
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UIControl || current is UITextField || current is UITextView {
                return false
            }
            let name = String(describing: type(of: current))
            if name.contains("TextField")
                || name.contains("TextView")
                || name.contains("Button")
                || name.contains("Switch")
                || name.contains("Slider")
                || name.contains("Segmented")
            {
                return false
            }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

private struct FormKeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> FormKeyboardDismissInstallerView {
        FormKeyboardDismissInstallerView()
    }

    func updateUIView(_ uiView: FormKeyboardDismissInstallerView, context: Context) {}
}

extension View {
    /// - Scroll does **not** dismiss the keyboard (content can still scroll above it).
    /// - Dismiss via keyboard Done, field submit (return/continue), or tap on empty form chrome.
    /// - Taps on buttons / text fields are not blocked.
    func formKeyboardBehavior(dismiss: @escaping () -> Void) -> some View {
        scrollDismissesKeyboard(.never)
            .background(FormKeyboardDismissInstaller())
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done", action: dismiss)
                }
            }
    }
}
#else
extension View {
    func formKeyboardBehavior(dismiss: @escaping () -> Void) -> some View {
        self
    }
}
#endif
