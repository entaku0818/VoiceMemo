//
//  File.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 24.9.2022.
//

import Foundation
import CoreData

class ThemaRepository: NSObject {

    static let shared = ThemaRepository()

    let container: NSPersistentContainer
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?

    var entityName: String = "Thema"

    override init() {

        container = NSPersistentContainer(name: entityName)
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
                Logger.shared.logError("ThemaRepository:" + error.localizedDescription)

            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true

        self.managedContext = container.viewContext
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext) {
            self.entity = localEntity
        }
    }

    func insert(state: String) {
        let thema:Thema?
        let fetchRequest: NSFetchRequest<Thema> = Thema.fetchRequest()
        do {
            thema = try managedContext.fetch(fetchRequest).first
            if thema == nil {
                if let thema = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? Thema {

                    thema.text = ""


                    do {
                        try managedContext.save()
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
            }else{
                thema?.text = state
                do {
                    try managedContext.save()
                } catch let error {
                    print(error.localizedDescription)
                }
            }
        } catch let error {
            Logger.shared.logError("ThemaRepository: insert" + error.localizedDescription)
            print(error.localizedDescription)
        }


    }

    func select() -> String {
        var text: String = ""

        let fetchRequest: NSFetchRequest<Thema> = Thema.fetchRequest()

        do {
            text = try managedContext.fetch(fetchRequest).first?.text ?? ""
        } catch let error {
            print(error.localizedDescription)
            Logger.shared.logError("ThemaRepository: select" + error.localizedDescription)
        }

        return text

    }


}
