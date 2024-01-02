//
//  Lock.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 2/1/2024.
//

import Foundation

/**
 A custom lock class that encapsulates the functionality of NSLock and provides
 a method to check if it's currently locked.
 */
class Lock {
    /// NSLock object used for synchronization.
    private var lockObject = NSLock()
    
    /// A flag indicating whether the lock is currently held.
    private var isLocked = false
    
    /**
     Acquires the lock.
     This method blocks until the lock is successfully acquired.
     */
    func lock() { lockObject.lock(); isLocked = true }
    
    /** 
     Releases the lock.
     This method should be called to release the lock after it has been acquired.
     */
    func unlock() { lockObject.unlock(); isLocked = false }
    
    /**
     Attempts to acquire the lock without blocking.
     - Returns: `true` if the lock was successfully acquired, otherwise `false`.
     */
    func `try`() -> Bool {
        let success = lockObject.try()
        if success { isLocked = true }
        return success
    }
    
    /**
     Checks if the lock is currently held.
     - Returns: `true` if the lock is currently held, otherwise `false`.
     */
    func check() -> Bool { return isLocked }
}
