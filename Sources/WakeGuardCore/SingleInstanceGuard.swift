import Foundation

/// Process-wide single-instance guard backed by an advisory file lock (`flock`).
///
/// The kernel releases the lock automatically when the process exits for ANY
/// reason — clean quit, crash, or `kill -9` — so there is no stale-lock problem
/// and no PID bookkeeping. This works regardless of how the app was launched
/// (bundle double-click or bare binary).
public final class SingleInstanceGuard {
    private let fileDescriptor: Int32

    /// Default lock location under the user's Application Support directory.
    public static let defaultPath =
        NSHomeDirectory() + "/Library/Application Support/WakeGuard/instance.lock"

    /// Returns `nil` when another instance already holds the lock — the caller
    /// should then exit. On success, KEEP the returned object alive for the
    /// whole process lifetime; releasing it frees the lock.
    ///
    /// If the lock file cannot be opened at all (an unexpected I/O error), this
    /// fails *open*: it returns a guard so the sole instance is never blocked by
    /// a transient error, and single-instance enforcement is simply skipped.
    public init?(lockPath: String = SingleInstanceGuard.defaultPath) {
        let dir = (lockPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir,
                                                 withIntermediateDirectories: true)

        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            self.fileDescriptor = -1   // fail open: no real lock is held
            return
        }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return nil                 // another instance holds the lock
        }
        self.fileDescriptor = fd
    }

    deinit {
        guard fileDescriptor >= 0 else { return }
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}
