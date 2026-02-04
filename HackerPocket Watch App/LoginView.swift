//
//  LoginView.swift
//  HackerPocket Watch App
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: HNAuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Sign In")
                    .font(.headline)

                Text("Log in with your Hacker News account to post comments.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(.password)

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    authManager.login(username: username, password: password)
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                    } else {
                        Text("Log In")
                            .fontWeight(.semibold)
                    }
                }
                .tint(.orange)
                .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Account")
        .onChange(of: authManager.isLoggedIn) { _, loggedIn in
            if loggedIn { dismiss() }
        }
    }
}

struct AccountView: View {
    @EnvironmentObject var authManager: HNAuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)

                Text("Signed In")
                    .font(.headline)

                Text(authManager.username)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    authManager.logout()
                    dismiss()
                } label: {
                    Text("Sign Out")
                }
            }
            .padding()
        }
        .navigationTitle("Account")
    }
}

#Preview("Login") {
    LoginView()
        .environmentObject(HNAuthManager())
}

#Preview("Account") {
    AccountView()
        .environmentObject(HNAuthManager())
}
