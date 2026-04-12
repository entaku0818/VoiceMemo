//
//  CoreDataStack.swift
//  VoiLog
//
//  Created by Claude on 2025/01/14.
//

import Foundation
import CoreData

/// Shared Core Data stack to ensure thread safety and prevent multiple container instances.
/// All Core Data operations should use this singleton to avoid crashes from concurrent access.
@MainActor
final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    let viewContext: NSManagedObjectContext

    private init() {
        container = NSPersistentContainer(name: "Voice")
        container.loadPersistentStores { storeDescription, loadError in
            if loadError != nil {
                // Attempt recovery by removing the corrupted store file
                if let storeURL = storeDescription.url {
                    try? FileManager.default.removeItem(at: storeURL)
                    try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                    try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                }
            }
        }
        // Retry after potential recovery
        if container.persistentStoreCoordinator.persistentStores.isEmpty {
            container.loadPersistentStores { _, retryError in
                if let retryError = retryError as NSError? {
                    // Log but do not crash — app will degrade gracefully
                    print("[CoreDataStack] Persistent store unavailable: \(retryError)")
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext = container.viewContext
    }

    /// Entity description for Voice entity
    var voiceEntity: NSEntityDescription? {
        NSEntityDescription.entity(forEntityName: "Voice", in: viewContext)
    }
}
