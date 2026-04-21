import SwiftUI
import Contacts
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var showingAddFriend = false
    @State private var showingSettings = false
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
                if let username = authService.currentUser?.username {
                    Button(action: { showingSettings = true }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.warmCoral)
                                .frame(width: 7, height: 7)
                            Text("@\(username)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.warmBrown)
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddFriend = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.warmCoral)
                }
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
        .onAppear {
            viewModel.loadChats()
            Task {
                await viewModel.syncChats()
                await viewModel.loadFriends()
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.warmPeach.opacity(0.6))
                    .frame(width: 160, height: 160)
                    .blur(radius: 2)
                Circle()
                    .stroke(Color.warmCoral.opacity(0.18), lineWidth: 1)
                    .frame(width: 200, height: 200)
                Image(systemName: "waveform")
                    .font(.system(size: 50, weight: .ultraLight))
                    .foregroundStyle(Color.warmCoral)
            }
            VStack(spacing: 8) {
                Text("say hi")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(Color.warmDark)
                    .tracking(3)
                Text("add a friend to start a tone")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.warmBrown)
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
                .padding(.vertical, 17)
                .background(Color.warmCoral)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color.warmCoral.opacity(0.3), radius: 14, y: 6)
            }
            .padding(.horizontal, 32)
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
        let name = friend.username ?? friend.displayName
        let initial = String(name.prefix(1)).uppercased()
        let isOpening = openingFriendId == friend.id
        return Button(action: { openFriend(friend) }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.warmPeach)
                        .frame(width: 58, height: 58)
                    if isOpening {
                        Circle()
                            .stroke(Color.warmCoral.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 58, height: 58)
                            .scaleEffect(1.2)
                            .opacity(0.6)
                    }
                    Text(initial)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color.warmCoral)
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
        let msgCount = LocalStorage.shared.loadMessages(chat.id).count
        let unheard = LocalStorage.shared.getUnheardCount(chatId: chat.id)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.warmPeach)
                    .frame(width: 50, height: 50)
                Text(String(chat.name.replacingOccurrences(of: "@", with: "").prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.warmCoral)
                if unheard > 0 {
                    Circle()
                        .fill(Color.callGreen)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.warmCream, lineWidth: 2))
                        .offset(x: 18, y: -18)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.name.lowercased())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.warmDark)
                    .lineLimit(1)
                Text(unheard > 0
                        ? "\(unheard) new \(unheard == 1 ? "tone" : "tones")"
                        : (msgCount == 0 ? "tap to say hi" : "\(msgCount) \(msgCount == 1 ? "tone" : "tones")"))
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(unheard > 0 ? Color.callGreen : Color.warmBrown.opacity(0.8))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.warmBrown.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.85))
        )
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
    @State private var contactsFriends: [TonesUser] = []
    @State private var isLoadingContacts = false

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.warmPeach.opacity(0.6))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 34, weight: .ultraLight))
                                    .foregroundStyle(Color.warmCoral)
                            }
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

                        Button(action: loadContacts) {
                            HStack(spacing: 10) {
                                if isLoadingContacts {
                                    ProgressView()
                                        .tint(Color.warmCoral)
                                } else {
                                    Image(systemName: "person.2.circle")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                Text("find from contacts")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(Color.warmDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.white.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if !contactsFriends.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("from your contacts")
                                    .font(.system(size: 12, weight: .medium))
.foregroundStyle(Color.warmBrown.opacity(0.7))
                    .tracking(2)
                    .textCase(.uppercase)

                                ForEach(contactsFriends) { friend in
                                    Button(action: { addContactFriend(friend) }) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color.warmPeach)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Text(String((friend.username ?? friend.displayName).prefix(1)).uppercased())
                                                        .font(.system(size: 16, weight: .light))
                                                        .foregroundStyle(Color.warmCoral)
                                                )
                                            VStack(alignment: .leading, spacing: 2) {
                                                if let u = friend.username {
                                                    Text("@\(u)")
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundStyle(Color.warmDark)
                                                }
                                                Text(friend.displayName)
                                                    .font(.system(size: 12, weight: .light))
                                                    .foregroundStyle(Color.warmBrown.opacity(0.8))
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color.warmCoral)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
.background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
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
                let friendName = user.username.map { "@\($0)" } ?? user.displayName
                _ = try await viewModel.createDM(with: user.id, friendName: friendName)
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.success)
                dismiss()
            } catch {
                addError = error.localizedDescription
            }
            isAdding = false
        }
    }

    private func loadContacts() {
        isLoadingContacts = true
        Task {
            let phoneNumbers = await fetchPhoneNumbers()
            var found: [TonesUser] = []
            for phone in phoneNumbers.prefix(20) {
                do {
                    let users = try await APIClient.shared.searchUsers(query: phone)
                    found.append(contentsOf: users)
                } catch { }
            }
            let existingFriendIds = Set(viewModel.friends.map { $0.id })
            contactsFriends = found.filter { !existingFriendIds.contains($0.id) && $0.id != authService.currentUser?.id }
            isLoadingContacts = false
        }
    }

    private func addContactFriend(_ friend: TonesUser) {
        Task {
            do {
                try await APIClient.shared.addFriend(friendId: friend.id)
                let name = friend.username.map { "@\($0)" } ?? friend.displayName
                _ = try await viewModel.createDM(with: friend.id, friendName: name)
                await viewModel.loadFriends()
                contactsFriends.removeAll { $0.id == friend.id }
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.success)
            } catch {
                addError = error.localizedDescription
            }
        }
    }

    private func fetchPhoneNumbers() async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let store = CNContactStore()
                var numbers: [String] = []
                let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                do {
                    try store.enumerateContacts(with: request) { contact, stop in
                        for phone in contact.phoneNumbers {
                            let digits = phone.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                            if digits.count >= 7 {
                                numbers.append(digits)
                            }
                        }
                    }
                } catch { }
                continuation.resume(returning: numbers)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsSheet: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                VStack(spacing: 32) {
                    Spacer()

                    if let username = authService.currentUser?.username {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.warmPeach.opacity(0.6))
                                    .frame(width: 110, height: 110)
                                Text(String(username.prefix(1)).uppercased())
                                    .font(.system(size: 42, weight: .thin))
                                    .foregroundStyle(Color.warmCoral)
                            }
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

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthService.shared)
    }
}
