import SwiftUI

// MARK: - Comment sheet

struct CommentSheetView: View {
    let post: CommunityPost
    let currentUserId: String
    @ObservedObject var communityVM: CommunityViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [PostComment] = []
    @State private var isLoading = true
    @State private var isPosting = false
    @State private var draftText = ""
    @State private var errorMessage: String? = nil
    @State private var resolvedCurrentUserId = ""
    @FocusState private var inputFocused: Bool

    private let service = SupabaseCommunityService()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.95)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color("EmpireMint").opacity(0.14), .clear],
                    center: .top, startRadius: 20, endRadius: 280
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: Thread list
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color("EmpireMint"))
                            .scaleEffect(1.2)
                        Spacer()
                    } else if comments.isEmpty {
                        emptyState
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(spacing: 0) {
                                    ForEach(comments) { comment in
                                        CommentRow(
                                            comment: comment,
                                            currentUserId: resolvedCurrentUserId,
                                            onDelete: {
                                                Task { await deleteComment(comment) }
                                            }
                                        )
                                        .id(comment.id)
                                        Divider()
                                            .background(Color.white.opacity(0.07))
                                            .padding(.leading, 62)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .onChange(of: comments.count) { _, _ in
                                if let last = comments.last {
                                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                                }
                            }
                        }
                    }

                    // MARK: Composer
                    composerBar
                }

                // Error toast
                if let err = errorMessage {
                    VStack {
                        TopToast(text: err)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 4)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .zIndex(10)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await bootstrap() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(Color("EmpireMint").opacity(0.4))
            Text("No comments yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Be the first to say something about this build.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Composer bar

    private var composerBar: some View {
        HStack(spacing: 10) {
            // Text field
            ZStack(alignment: .leading) {
                if draftText.isEmpty {
                    Text("Add a comment…")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 14)
                }
                TextField("", text: $draftText, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .onChange(of: draftText) { _, new in
                        if new.count > 500 { draftText = String(new.prefix(500)) }
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        draftText.isEmpty
                            ? LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color("EmpireMint").opacity(0.7), Color("EmpireMint").opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )

            // Send button
            Button {
                Task { await submitComment() }
            } label: {
                if isPosting {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.85)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? Color("EmpireMint").opacity(0.3)
                                         : Color("EmpireMint"))
                }
            }
            .buttonStyle(.plain)
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: draftText.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().background(Color.white.opacity(0.08))
                }
        )
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        do {
            comments = try await service.fetchComments(postId: post.id)
        } catch {
            showError(error.localizedDescription)
        }
        isLoading = false
    }

    private func submitComment() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPosting = true
        let draft = draftText
        draftText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        do {
            let comment = try await service.postComment(
                postId: post.id,
                preferredUserId: resolvedCurrentUserId.isEmpty ? currentUserId : resolvedCurrentUserId,
                body: trimmed
            )
            await MainActor.run {
                comments.append(comment)
                // Bump local count in the VM so the button badge updates
                communityVM.incrementCommentCount(postId: post.id)
                isPosting = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                draftText = draft
                isPosting = false
                showError(error.localizedDescription)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func deleteComment(_ comment: PostComment) async {
        do {
            try await service.deleteComment(commentId: comment.id)
            await MainActor.run {
                comments.removeAll { $0.id == comment.id }
                communityVM.decrementCommentCount(postId: post.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func bootstrap() async {
        do {
            resolvedCurrentUserId = try await service.authenticatedUserId()
        } catch {
            resolvedCurrentUserId = currentUserId
        }
        await loadComments()
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { errorMessage = nil }
        }
    }
}

// MARK: - Comment row

private struct CommentRow: View {
    let comment: PostComment
    let currentUserId: String
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @State private var dragOffset: CGFloat = 0

    private var isOwn: Bool {
        comment.userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private let revealWidth: CGFloat = 92
    private var revealedWidth: CGFloat { max(0, -dragOffset) }
    private var isDeleteRevealed: Bool { revealedWidth > 12 }

    var body: some View {
        ZStack(alignment: .trailing) {
            if isOwn {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: revealWidth)
                            .frame(maxHeight: .infinity)
                    }
                    .tint(.red)
                    .buttonStyle(.borderless)
                    .opacity(isDeleteRevealed ? 1 : 0)
                    .allowsHitTesting(isDeleteRevealed)
                }
                .frame(width: revealedWidth)
                .clipped()
            }

            HStack(alignment: .top, spacing: 10) {
                avatarView
                    .frame(width: 34, height: 34)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(comment.username ?? "Driver")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                            .font(.caption2)
                        Text(comment.createdAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                    }

                    Text(comment.body)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clear)
            .offset(x: dragOffset)
            .contentShape(Rectangle())
            .allowsHitTesting(!(isOwn && isDeleteRevealed))
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard isOwn else { return }
                    let proposed = value.translation.width
                    dragOffset = max(-revealWidth, min(0, proposed))
                }
                .onEnded { value in
                    guard isOwn else { return }
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        dragOffset = value.translation.width < -40 ? -revealWidth : 0
                    }
                }
        )
        .onTapGesture {
            if dragOffset != 0 {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    dragOffset = 0
                }
            }
        }
        .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var avatarView: some View {
        Group {
            if let path = comment.avatarPath,
               let url = SupabaseCommunityService().avatarPublicURL(for: path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Image(systemName: "person.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color("EmpireMint").opacity(0.7))
        }
    }
}

// MARK: - Date extension (shared with ExploreFeedView)

extension Date {
    var relativeFormatted: String {
        let seconds = -timeIntervalSinceNow
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 604800 { return "\(Int(seconds / 86400))d ago" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: self)
    }
}
