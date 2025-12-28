//
//  MessageInputView.swift
//  Achieva
//
//  Message input component with text field and send button - redesigned to match HTML
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    let onSend: (String) -> Void
    let onSendMedia: (Data, MessageType) -> Void
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(.separator).opacity(0.5))
            
            HStack(spacing: 8) {
                // Image picker button
                Button {
                    showingImagePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                }
                
                // Text input
                HStack(spacing: 12) {
                    TextField("Message...", text: $text, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...5)
                }
                .frame(minHeight: 36)
                
                // Send button
                Button {
                    let messageText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !messageText.isEmpty {
                        onSend(messageText)
                        text = ""
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                            .frame(width: 36, height: 36)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -2)
            )
            .background(.ultraThinMaterial)
            
            // Home indicator spacer
            Rectangle()
                .fill(Color.clear)
                .frame(height: 32)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                onSendMedia(imageData, .image)
                selectedImage = nil
            }
        }
    }
}

// Simple image picker wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
