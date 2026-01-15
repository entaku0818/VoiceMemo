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
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
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
