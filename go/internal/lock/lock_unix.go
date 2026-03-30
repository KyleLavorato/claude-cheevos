//go:build !windows

package lock

import (
    "fmt"
    "os"
    "syscall"
    "time"
)

// FileLock is a cross-platform advisory exclusive file lock.
type FileLock struct {
    path string
    f    *os.File
}

// New creates a FileLock for the given path. The lock file is created if needed.
func New(path string) *FileLock {
    return &FileLock{path: path}
}

// Lock acquires the exclusive lock, retrying until timeout elapses.
func (l *FileLock) Lock(timeout time.Duration) error {
    f, err := os.OpenFile(l.path, os.O_CREATE|os.O_WRONLY, 0600)
    if err != nil {
        return fmt.Errorf("lock: open %s: %w", l.path, err)
    }
    l.f = f

    deadline := time.Now().Add(timeout)
    for {
        err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
        if err == nil {
            return nil
        }
        if time.Now().After(deadline) {
            f.Close()
            l.f = nil
            return fmt.Errorf("lock: timeout acquiring %s after %v", l.path, timeout)
        }
        time.Sleep(100 * time.Millisecond)
    }
}

// Unlock releases the lock and closes the lock file.
func (l *FileLock) Unlock() {
    if l.f != nil {
        syscall.Flock(int(l.f.Fd()), syscall.LOCK_UN) //nolint:errcheck
        l.f.Close()
        l.f = nil
    }
}
