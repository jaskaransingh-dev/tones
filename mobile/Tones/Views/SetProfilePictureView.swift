import SwiftUI
import PhotosUI

struct SetProfilePictureView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var rawImageData: Data?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showCameraPicker = false
    @State private var showPhotosPicker = false

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        if let uiImage = avatarImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.warmPeach.opacity(0.6))
                                .frame(width: 140, height: 140)
                            Image(systemName: "camera")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundStyle(Color.warmCoral)
                        }
                    }

                    Text("add a profile picture")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(Color.warmDark)
                        .tracking(2)

                    Text("let others know who you are")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.warmBrown)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button(action: { showCameraPicker = true }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.system(size: 16))
                            Text("take a photo")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(rawImageData == nil ? Color.warmCoral : Color.warmCoral.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(rawImageData != nil)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 16))
                            Text("choose from library")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(rawImageData == nil ? Color.warmCoral.opacity(0.85) : Color.warmCoral.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: rawImageData != nil)
                    }
                    .disabled(rawImageData != nil)

                    if rawImageData != nil {
                        Button(action: uploadAvatar) {
                            HStack {
                                if isUploading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("looks good")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.warmCoral)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.warmCoral.opacity(0.25), radius: 12, y: 6)
                        }
                        .disabled(isUploading)
                    }

                    Button(action: skipAvatar) {
                        Text("skip for now")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.warmBrown.opacity(0.6))
                    }
                    .padding(.top, 4)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    processImage(data)
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    processImage(data)
                }
            }
        }
    }

    private func processImage(_ data: Data) {
        guard let uiImage = UIImage(data: data),
              let resized = uiImage.resized(to: CGSize(width: 400, height: 400)),
              let compressed = resized.jpegData(compressionQuality: 0.7) else {
            errorMessage = "Failed to process image"
            return
        }
        rawImageData = compressed
        avatarImage = resized
        errorMessage = nil
    }

    private func uploadAvatar() {
        guard let data = rawImageData else { return }
        errorMessage = nil
        isUploading = true
        Task {
            do {
                try await authService.uploadAvatar(data)
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploading = false
            dismiss()
        }
    }

    private func skipAvatar() {
        isUploading = true
        Task {
            do {
                try await authService.skipAvatar()
            } catch {
                authService.currentUser?.avatarURL = "none"
            }
            isUploading = false
            dismiss()
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}