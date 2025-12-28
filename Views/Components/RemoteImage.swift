//
//  RemoteImage.swift
//  Achieva
//
//  Custom image loader with caching and better error handling for Supabase Storage
//

import SwiftUI

struct RemoteImage: View {
    let url: URL?
    let placeholder: AnyView
    let contentMode: ContentMode
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    
    init(
        url: URL?,
        placeholder: AnyView = AnyView(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
        ),
        contentMode: ContentMode = .fill
    ) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if hasFailed {
                // Failed to load - don't show anything
                EmptyView()
            } else if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading, !hasFailed else { return }
        isLoading = true
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            print("✅ Image loaded from cache: \(url.lastPathComponent)")
            loadedImage = cachedImage
            isLoading = false
            return
        }
        
        // Load from network
        print("📥 Loading image from: \(url.absoluteString)")
        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 10.0
                request.cachePolicy = .returnCacheDataElseLoad
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Image response status: \(httpResponse.statusCode) for \(url.lastPathComponent)")
                    
                    if httpResponse.statusCode == 200 {
                        if let image = UIImage(data: data) {
                            // Cache the image
                            ImageCache.shared.set(image, forKey: url.absoluteString)
                            await MainActor.run {
                                loadedImage = image
                                isLoading = false
                                print("✅ Image loaded successfully: \(url.lastPathComponent)")
                            }
                        } else {
                            print("⚠️ Failed to create UIImage from data for: \(url.lastPathComponent)")
                            await MainActor.run {
                                hasFailed = true
                                isLoading = false
                            }
                        }
                    } else {
                        print("❌ Image load failed with status \(httpResponse.statusCode) for: \(url.lastPathComponent)")
                        await MainActor.run {
                            hasFailed = true
                            isLoading = false
                        }
                    }
                } else {
                    print("⚠️ Unexpected response type for: \(url.lastPathComponent)")
                    await MainActor.run {
                        hasFailed = true
                        isLoading = false
                    }
                }
            } catch {
                print("❌ Error loading image from \(url.absoluteString): \(error)")
                await MainActor.run {
                    hasFailed = true
                    isLoading = false
                }
            }
        }
    }
}

// Image cache using NSCache
class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Limit to 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Rough memory cost
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

