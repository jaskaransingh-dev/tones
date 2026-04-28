import SwiftUI
import PhotosUI

struct GroupSettingsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var chat: LocalChat
    @Environment(\.dismiss) private var dismiss

    @State private var groupTitle: String
    @State private var avatarImage: UIImage?
    @State private var avatarData: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPhotoPicker = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    init(viewModel: HomeViewModel, chat: Binding<LocalChat>) {
        self.viewModel = viewModel
        self._chat = chat
        self._groupTitle = State(initialValue: chat.wrappedValue.displayName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            avatarSection
                            nameSection
                        }

                        membersSection

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button(action: saveChanges) {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("save")
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
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadPhoto(from: newItem)
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Menu {
                if isCameraAvailable {
                    Button(action: { showCamera = true }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
                Button(action: { showPhotoPicker = true }) {
                    Label("Choose from Library", systemImage: "photo")
                }
                if avatarImage != nil {
                    Button(role: .destructive, action: { avatarImage = nil; avatarData = "none" }) {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.warmPeach.opacity(0.4))
                        .frame(width: 120, height: 120)

                    if let img = avatarImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else if let urlString = chat.avatarURL, !urlString.isEmpty, urlString != "none" {
                        GroupAvatarImageView(urlString: urlString)
                            .frame(width: 120, height: 120)
                    } else {
                        Image("TonesLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    }

                    Circle()
                        .strokeBorder(Color.warmCoral.opacity(0.3), lineWidth: 2)
                        .frame(width: 120, height: 120)

                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.warmCoral)
                        .background(Circle().fill(Color.warmCream).frame(width: 20, height: 20))
                        .offset(x: 38, y: 38)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Text("tap to change photo")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color.warmBrown.opacity(0.6))
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                avatarImage = image
                avatarData = imageToBase64(image)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("group name")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.warmBrown)
                .tracking(3)
                .textCase(.uppercase)

            TextField("name your group", text: $groupTitle)
                .font(.title3)
                .foregroundStyle(Color.warmDark)
                .padding()
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("members")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.warmBrown)
                    .tracking(3)
                    .textCase(.uppercase)
                Spacer()
                Text("\(chat.members?.count ?? 0)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.warmBrown.opacity(0.7))
            }

            LazyVStack(spacing: 4) {
                ForEach(chat.members ?? []) { member in
                    memberRow(member)
                }
            }
        }
    }

    private func memberRow(_ member: LocalChatMember) -> some View {
        let isMe = member.id == AuthService.shared.currentUser?.id
        let name = member.username ?? "user"
        return HStack(spacing: 12) {
            AvatarView(urlString: member.avatarURL, initial: String(name.prefix(1)).uppercased(), size: 38)

            Text(name.lowercased())
                .font(.system(size: 15, weight: isMe ? .semibold : .medium))
                .foregroundStyle(Color.warmDark)

            if isMe {
                Text("(you)")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.warmBrown.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    avatarImage = image
                    avatarData = imageToBase64(image)
                }
            }
        }
    }

    private func imageToBase64(_ image: UIImage) -> String {
        guard image.size.width > 0, image.size.height > 0 else { return "none" }
        let maxSize: CGFloat = 400
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        let data = resized.jpegData(compressionQuality: 0.75) ?? Data()
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }

    private func saveChanges() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await viewModel.updateGroupChat(
                    chatId: chat.id,
                    title: groupTitle.isEmpty ? nil : groupTitle,
                    avatarData: avatarData
                )
                await MainActor.run {
                    chat.name = groupTitle
                    chat.avatarURL = avatarData
                }
                dismiss()
            } catch let error as TonesAuthError {
                errorMessage = error.message
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct GroupAvatarImageView: View {
    let urlString: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.warmPeach)
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        if urlString.hasPrefix("data:"), let data = Data(base64Encoded: urlString.split(separator: ",").last.map { String($0) } ?? ""),
           let img = UIImage(data: data) {
            image = img
            return
        }
        guard let url = URL(string: urlString) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let img = UIImage(data: data) {
                    await MainActor.run { image = img }
                }
            } catch {
                await MainActor.run { image = nil }
            }
        }
    }
}