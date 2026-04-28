import SwiftUI
import Contacts
import ContactsUI
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var notificationRouter = NotificationRouter.shared
    @State private var showingAddFriend = false
    @State private var showingSettings = false
    @State private var showingCreateGroup = false
    @State private var openingFriendId: String? = nil
    @State private var pendingChat: LocalChat? = nil

    var body: some View {
        ZStack {
            WarmBackground()

            if viewModel.chats.isEmpty && viewModel.friends.isEmpty {
                emptyView
            } else {
                mainList
            }

        }
        .navigationDestination(isPresented: Binding(
            get: { pendingChat != nil },
            set: { if !$0 { pendingChat = nil } }
        )) {
            if let chat = pendingChat {
                ChatView(chat: chat, viewModel: viewModel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { showingSettings = true }) {
                    AvatarView(
                        urlString: authService.currentUser?.avatarURL,
                        initial: String((authService.currentUser?.username ?? "").prefix(1)).uppercased(),
                        size: 30
                    )
                }
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image("TonesLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    Text("tones")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.warmDark)
                        .tracking(4)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 18) {
                    Button(action: { showingCreateGroup = true }) {
                        Image(systemName: "person.2")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color.warmDark.opacity(0.75))
                    }
                    Button(action: { showingAddFriend = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.warmCoral)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupChatView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
        .onAppear {
            viewModel.loadChats()
            viewModel.loadFriends()
            authService.registerForPushNotifications()
            Task {
                await viewModel.syncChats()
                viewModel.refreshUnreadCounts()
            }
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .onChange(of: notificationRouter.pendingChatId) { _, chatId in
            guard let chatId else { return }
            if let chat = viewModel.chats.first(where: { $0.id == chatId }) {
                pendingChat = chat
            } else {
                Task {
                    if let chat = try? await viewModel.createDMIfExists(chatId: chatId) {
                        pendingChat = chat
                    }
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 32) {
            Spacer()
            Image("TonesLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .shadow(color: Color.warmCoral.opacity(0.18), radius: 28, y: 12)
            VStack(spacing: 10) {
                Text("tones")
                    .font(.system(size: 34, weight: .thin, design: .rounded))
                    .foregroundStyle(Color.warmDark)
                    .tracking(8)
                Text("voice messages, nothing else")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.warmBrown.opacity(0.8))
                    .tracking(1)
            }
            Spacer()
            Button(action: { showingAddFriend = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("add a friend")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.warmCoral)
                .clipShape(RoundedRectangle(cornerRadius: TonesRadius.card))
                .shadow(color: Color.warmCoral.opacity(0.28), radius: 14, y: 6)
            }
            .padding(.horizontal, TonesSpacing.xl)
            .padding(.bottom, 50)
        }
    }

    private var mainList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                friendsStrip
                chatsSection
            }
            .padding(.bottom, 80)
        }
    }

    private var friendsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("friends")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.warmBrown)
                    .tracking(3)
                    .textCase(.uppercase)
                Spacer()
                if !viewModel.friends.isEmpty {
                    Text("\(viewModel.friends.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.warmBrown.opacity(0.7))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    addFriendChip
                    ForEach(viewModel.friends) { friend in
                        friendChip(friend)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
        }
    }

    private var addFriendChip: some View {
        Button(action: { showingAddFriend = true }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.warmCoral.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                        .frame(width: 58, height: 58)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Color.warmCoral)
                }
                Text("add")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.warmBrown)
            }
            .frame(width: 64)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func friendChip(_ friend: TonesUser) -> some View {
        let name = friend.username ?? "user"
        let isOpening = openingFriendId == friend.id
        return Button(action: { openFriend(friend) }) {
            VStack(spacing: 8) {
                ZStack {
                    AvatarView(urlString: friend.avatarURL, initial: String(name.prefix(1)).uppercased(), size: 58)
                    if isOpening {
                        Circle()
                            .stroke(Color.warmCoral.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 58, height: 58)
                            .scaleEffect(1.2)
                            .opacity(0.6)
                    }
                }
                Text(name.lowercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.warmBrown)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
            .frame(width: 64)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.4).repeatForever(), value: isOpening)
    }

    private var chatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("tones")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.warmBrown)
                    .tracking(3)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 24)

            if viewModel.chats.isEmpty {
                VStack(spacing: 6) {
                    Text("no tones yet")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.warmBrown)
                    Text("tap a friend above to start")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.chats) { chat in
                        NavigationLink(destination: ChatView(chat: chat, viewModel: viewModel)) {
                            chatRow(chat: chat)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func chatRow(chat: LocalChat) -> some View {
        let unheard = chat.unreadCount
        let name = chat.displayName.replacingOccurrences(of: "@", with: "")
        let initial = String(name.prefix(1)).uppercased()
        return HStack(spacing: 14) {
            if chat.isGroup {
                groupAvatar(chat: chat)
            } else {
                ZStack {
                    AvatarView(urlString: chat.peerAvatarURL, initial: initial, size: 50)
                    if unheard > 0 {
                        Circle()
                            .fill(Color.callGreen)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Text("\(unheard)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 18, y: -18)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if chat.isGroup {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.warmBrown.opacity(0.6))
                    }
                    Text(chat.isGroup ? name : name.lowercased())
                        .font(.system(size: 16, weight: unheard > 0 ? .semibold : .medium))
                        .foregroundStyle(Color.warmDark)
                        .lineLimit(1)
                }
                Text(unheard > 0
                        ? "\(unheard) new \(unheard == 1 ? "tone" : "tones")"
                        : "\(LocalStorage.shared.loadMessages(chat.id).count) tones")
                    .font(.system(size: 12, weight: unheard > 0 ? .medium : .light))
                    .foregroundStyle(unheard > 0 ? Color.callGreen : Color.warmBrown.opacity(0.8))
            }

            Spacer()

            if unheard > 0 {
                Circle()
                    .fill(Color.callGreen)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.warmBrown.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: TonesRadius.card)
                .fill(unheard > 0 ? Color.callGreen.opacity(0.07) : Color.white.opacity(0.7))
        )
    }

    private func groupAvatar(chat: LocalChat) -> some View {
        let members = chat.members ?? []
        let hasGroupAvatar = chat.avatarURL != nil && !(chat.avatarURL?.isEmpty ?? true) && chat.avatarURL != "none"
        let avatars: [(url: String?, initial: String)] = {
            if hasGroupAvatar { return [] }
            let others = members.filter { $0.id != AuthService.shared.currentUser?.id }
            if others.isEmpty { return [(url: nil, initial: "?")] }
            return others.prefix(3).map { (url: $0.avatarURL, initial: String(($0.username ?? "?").prefix(1)).uppercased()) }
        }()
        let unheard = chat.unreadCount

        return ZStack {
            if hasGroupAvatar {
                AvatarView(urlString: chat.avatarURL, initial: String(chat.displayName.prefix(1)).uppercased(), size: 50)
            } else {
                Group {
                    if avatars.count >= 3 {
                        AvatarView(urlString: avatars[2].url, initial: avatars[2].initial, size: 28)
                            .offset(x: 14, y: 14)
                            .zIndex(0)
                    }
                    if avatars.count >= 2 {
                        AvatarView(urlString: avatars[1].url, initial: avatars[1].initial, size: 28)
                            .offset(x: -14, y: 14)
                            .zIndex(1)
                    }
                    AvatarView(urlString: avatars.first?.url, initial: avatars.first?.initial ?? "?", size: 34)
                        .zIndex(2)
                }
                .frame(width: 50, height: 50)
            }

            if unheard > 0 {
                Circle()
                    .fill(Color.callGreen)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Text("\(unheard)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    )
                    .offset(x: 18, y: -18)
            }
        }
    }

    private func openFriend(_ friend: TonesUser) {
        guard openingFriendId == nil else { return }
        openingFriendId = friend.id
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()
        Task {
            do {
                let chat = try await viewModel.openChat(with: friend)
                pendingChat = chat
            } catch {
                print("openChat failed: \(error)")
            }
            openingFriendId = nil
        }
    }
}

struct AddFriendView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var addError: String?
    @State private var isAdding = false
    @State private var showingShare = false
    @State private var showingContactPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        VStack(spacing: 14) {
                            Image("TonesLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                            Text("add a friend")
                                .font(.system(size: 24, weight: .thin))
                                .foregroundStyle(Color.warmDark)
                                .tracking(2)
                        }

                        VStack(spacing: 16) {
                            TextField("@username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.title3)
                                .foregroundStyle(Color.warmDark)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .onChange(of: username) { _, newValue in
                                    username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                                    addError = nil
                                }

                            if let addError {
                                Text(addError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Button(action: addFriend) {
                                HStack {
                                    if isAdding {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("add")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(username.count >= 3 ? Color.warmCoral : Color.warmCoral.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: Color.warmCoral.opacity(username.count >= 3 ? 0.25 : 0), radius: 12, y: 6)
                            }
                            .disabled(username.count < 3 || isAdding)
                        }

                        Divider()
                            .foregroundStyle(Color.warmBrown.opacity(0.15))

                        Button(action: { showingShare = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .medium))
                                Text("share your link")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(Color.warmDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
.background(Color.white.opacity(0.85))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .sheet(isPresented: $showingShare) {
                            if let username = authService.currentUser?.username {
                                ShareSheet(activityItems: [
                                    "Add me on Tones! @\(username) https://apps.apple.com/app/tones"
                                ])
                            }
                        }

                        Button(action: { showingContactPicker = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.2.circle")
                                    .font(.system(size: 16, weight: .medium))
                                Text("invite from contacts")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(Color.warmDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.white.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .sheet(isPresented: $showingContactPicker) {
                            ContactPickerView { contact in
                                handlePickedContact(contact)
                            }
                            .ignoresSafeArea()
                        }
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
    }

    private func addFriend() {
        isAdding = true
        addError = nil
        Task {
            do {
                let user = try await viewModel.addFriend(byUsername: username)
                let friendName = user.username.map { "@\($0)" } ?? "user"
                _ = try await viewModel.createDM(with: user.id, friendName: friendName)
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.success)
                dismiss()
            } catch let error as TonesAuthError {
                addError = error.message
            } catch {
                addError = error.localizedDescription
            }
            isAdding = false
        }
    }

    private func handlePickedContact(_ contact: CNContact) {
        showingContactPicker = false
        guard let phone = contact.phoneNumbers.first?.value.stringValue else {
            addError = "That contact has no phone number."
            return
        }
        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let myHandle = authService.currentUser?.username.map { "@\($0)" } ?? ""
        let body = "hey, add me on tones \(myHandle) https://apps.apple.com/app/tones"
        guard let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:\(digits)&body=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}

struct ContactPickerView: UIViewControllerRepresentable {
    let onPick: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (CNContact) -> Void
        init(onPick: @escaping (CNContact) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(contact)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        if let popover = uiViewController.popoverPresentationController {
            popover.sourceView = uiViewController.view
            popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX, y: uiViewController.view.bounds.midY, width: 0, height: 0)
        }
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false
    @State private var showingProfilePicture = false
    @State private var showingPrivacyPolicy = false
    @AppStorage("saveRecordings") private var saveRecordings = true

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                VStack(spacing: 32) {
                    Spacer()

                    if let username = authService.currentUser?.username {
                        VStack(spacing: 14) {
                            Button(action: { showingProfilePicture = true }) {
                                ZStack {
                                    AvatarView(
                                        urlString: authService.currentUser?.avatarURL,
                                        initial: String(username.prefix(1)).uppercased(),
                                        size: 110
                                    )
                                    Circle()
                                        .stroke(Color.warmCoral.opacity(0.3), lineWidth: 2)
                                        .frame(width: 120, height: 120)
                                    Circle()
                                        .fill(Color.warmCoral.opacity(0.15))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.warmCoral)
                                        )
                                        .offset(x: 38, y: 38)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Text("@\(username)")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.warmDark)

                            HStack(spacing: 12) {
                                Button(action: { copyUsername(username) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 12))
                                        Text("copy")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(Color.warmCoral)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.7)))
                                }

                                Button(action: { showingShare = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 12))
                                        Text("share")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.warmCoral))
                                }
                            }
                            .sheet(isPresented: $showingShare) {
                                ShareSheet(activityItems: [
                                    "Add me on Tones! @\(username) https://apps.apple.com/app/tones"
                                ])
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("save recordings")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.warmDark)
                                    Text(saveRecordings ? "tones are kept until you delete them" : "tones are removed after delivery")
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundStyle(Color.warmBrown.opacity(0.7))
                                }
                                Spacer()
                                Toggle("", isOn: $saveRecordings)
                                    .labelsHidden()
                                    .tint(Color.warmCoral)
                                    .onChange(of: saveRecordings) { _, newValue in
                                        if !newValue {
                                            LocalStorage.shared.shouldSaveRecordings = false
                                            LocalStorage.shared.cleanupAllAudioIfNeeded()
                                        } else {
                                            LocalStorage.shared.shouldSaveRecordings = true
                                        }
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))
                        }

                        Button(action: { showingPrivacyPolicy = true }) {
                            Text("privacy policy")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.warmBrown.opacity(0.6))
                        }
                        Button(action: signOut) {
                            Text("sign out")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.warmCoral)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .sheet(isPresented: $showingProfilePicture) {
                SetProfilePictureView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicySheet()
            }
        }
    }

    private func copyUsername(_ username: String) {
        UIPasteboard.general.string = "@\(username)"
    }

    private func signOut() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            authService.logout()
        }
    }
}

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tones Voice Privacy Policy")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.warmDark)

                        Text("Effective Date: April 21, 2026")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Color.warmBrown)

                        VStack(alignment: .leading, spacing: 16) {
                            PolicySection(
                                title: "Information We Collect",
                                content: "We do not collect personal data or transmit it to external servers."
                            )

                            PolicySection(
                                title: "Audio Recordings",
                                content: "Voice messages are sent to recipients for delivery. You can choose whether recordings are saved on your device. When \"save recordings\" is off, local copies are removed after delivery."
                            )

                            PolicySection(
                                title: "Device Information",
                                content: "We do not collect analytics or tracking data."
                            )

                            PolicySection(
                                title: "Third-Party Services",
                                content: "We do not use third-party analytics or advertising."
                            )

                            PolicySection(
                                title: "Security",
                                content: "Your data is protected by your device security settings."
                            )

                            PolicySection(
                                title: "Children's Privacy",
                                content: "We do not knowingly collect data from children under 13."
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Contact")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.warmDark)
                                Text("jaskaransinghdoel@gmail.com")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundStyle(Color.warmBrown)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Changes")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.warmDark)
                                Text("We may update this policy in the future.")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundStyle(Color.warmBrown)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
    }
}

struct PolicySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.warmDark)
            Text(content)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color.warmBrown)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthService.shared)
    }
}
