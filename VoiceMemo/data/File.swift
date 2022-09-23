//
//  File.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 24.9.2022.
//

import Foundation
import UIKit
import CoreData

class PersonManager: NSObject {
    
    //AppDelegateの初期設定
    
    var managedContext: NSManagedObjectContext
    var entity: NSEntityDescription?
    
    var entityName: String = "VoiceMemo"
    
    override init(){
        self.managedContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        if let localEntity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)
        {
            self.entity = localEntity
        }
    }
    
    //データ追加処理
    //引数で追加データを渡して、内部で登録処理実施
    func insert(title: String, url: URL){
        if let voice = NSManagedObject(entity: self.entity!, insertInto: managedContext) as? VoiceMemo {
            
            voice.title = title
            voice.url = url
                        
            do {
                try managedContext.save()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    
    //データ検索処理
    //全件データを読み込んで表示
    //こちらも削除のNSPredicateを参考にして、検索処理は実装する
    func selectAllData() -> [VoiceMemo] {
        var memoGroups: [VoiceMemo] = []
        
        let fetchRequest: NSFetchRequest<VoiceMemo> = VoiceMemo.fetchRequest()

        do {
            memoGroups = try managedContext.fetch(fetchRequest)
        } catch let error {
            print(error.localizedDescription)
        }
        return memoGroups

    }
    
    
   
}
