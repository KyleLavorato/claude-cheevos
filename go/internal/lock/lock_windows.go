//go:build windows

package lock

import (
    "fmt"
    "os"
    "time"

    "golang.org/x/sys/windows"
)

// FileLock is a cross-platform advisory exclusive file lock.
type FileLock struct {
    path   string
    handle windows.Handle
}

// New creates a FileLock for the given path.
func New(path string) *FileLock {
    return &FileLock{path: path}
}

// Lock acquires the exclusive lock using LockFileEx, retrying until timeout.
func (l *FileLock) Lock(timeout time.Duration) error {
    pathUTF16, err := windows.UTF16PtrFromString(l.path)
    if err != nil {
        return fmt.Errorf("lock: UTF16 path: %w", err)
    }

    h, err := windows.CreateFile(
        pathUTF16,
        windows.GENERIC_READ|windows.GENERIC_WRITE,
        0,
        nil,
        windows.OPEN_ALWAYS,
        windows.FILE_ATTRIBUTE_NORMAL,
        0,
    )
    if err != nil {
        return fmt.Errorf("lock: CreateFile %s: %w", l.path, err)
    }
    l.handle = h

    deadline := time.Now().Add(timeout)
    ol := new(windows.Overlapped)
    for {
        err = windows.LockFileEx(h, windows.LOCKFILE_EXCLUSIVE_LOCK|windows.LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, ol)
        if err == nil {
            return nil
        }
        if time.Now().After(deadline) {
            windows.CloseHandle(h)
            l.handle = 0
            return fmt.Errorf("lock: timeout acquiring %s after %v", l.path, timeout)
        }
        time.Sleep(100 * time.Millisecond)
    }
}

// Unlock releases the lock.
func (l *FileLock) Unlock() {
    if l.handle != 0 {
        ol := new(windows.Overlapped)
        windows.UnlockFileEx(l.handle, 0, 1, 0, ol) //nolint:errcheck
        windows.CloseHandle(l.handle)
        l.handle = 0
    }
}

// tempFile is needed on Windows because os.CreateTemp writes to the same dir.
// Reexported from the lock package for use by the store.
func tempFile(dir, pattern string) (*os.File, error) {
    return os.CreateTemp(dir, pattern)
}
