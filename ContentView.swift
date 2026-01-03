//
//  ContentView.swift
//  Achieva
//
//  Simple tab view navigation
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Haptic feedback when switching tabs
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}

#Preview {
    ContentView()
}
