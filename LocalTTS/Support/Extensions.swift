import Foundation

extension Data {
    var utf8String: String {
        String(decoding: self, as: UTF8.self)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTapModifier())
    }
}

struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .onAppear {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    return
                }
                if let recognizers = window.gestureRecognizers,
                   recognizers.contains(where: { $0.name == "KeyboardDismissTap" }) {
                    return
                }
                let tap = UITapGestureRecognizer(target: TapDismissDelegate.shared, action: #selector(TapDismissDelegate.handleTap))
                tap.name = "KeyboardDismissTap"
                tap.cancelsTouchesInView = false
                tap.delegate = TapDismissDelegate.shared
                window.addGestureRecognizer(tap)
            }
        #else
        content
        #endif
    }
}

#if canImport(UIKit)
private class TapDismissDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = TapDismissDelegate()
    
    @objc func handleTap() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var currentView: UIView? = touch.view
        while let view = currentView {
            if view is UITextField || view is UITextView {
                return false
            }
            currentView = view.superview
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
#endif

