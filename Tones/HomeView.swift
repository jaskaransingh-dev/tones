import SwiftUI

struct HomeView: View {
    // Dummy data for demonstration; wire to real data later
    let friends = ["alice", "bob", "group: weekend"]
    
    var body: some View {
        NavigationStack {
            List(friends, id: \.self) { friend in
                NavigationLink(destination: ActiveTuneView(chatId: friend)) {
                    Text(friend)
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.vertical, 12)
                }
            }
            .navigationTitle("tune")
            .listStyle(.plain)
        }
    }
}

#Preview {
    HomeView()
}
