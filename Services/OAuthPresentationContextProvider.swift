//
//  OAuthPresentationContextProvider.swift
//  Achieva
//
//  Provides presentation context for ASWebAuthenticationSession
//

import AuthenticationServices
import UIKit

class OAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthPresentationContextProvider()
    
    private override init() {
        super.init()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            // Fallback to key window if available
            return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIWindow()
        }
        return window
    }
}


