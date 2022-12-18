//
//  CloudDAO.swift
//  TCMGuide
//
//  Created by Kevin Fan on 2022/12/6.
//  Copyright © 2022 Dobrinka Tabakova. All rights reserved.
//

import Foundation
import CloudKit
import UIKit

class CloudDAO {
    //static let database = CKContainer.default().publicCloudDatabase
    
    static let container: CKContainer = CKContainer(identifier: "iCloud.tcm")
    
    class func fetch(completion: @escaping (Result<String, Error>) -> ()) {
        
        
        let reachability = Reachability(hostName: "www.apple.com")
        if(reachability?.currentReachabilityStatus().rawValue == 0){
            let error = DBError.notAvailable("請檢查網路是否連線正常。")
            completion(.failure(error))
        }else{
            let database = container.publicCloudDatabase
            let predicate = NSPredicate(value: true)
            //let name = NSSortDescriptor(key: "MY_KEY", ascending: true)
            let query = CKQuery(recordType: "KEY", predicate: predicate)
            //query.sortDescriptors = [name]
            
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["MY_KEY"]
            operation.resultsLimit = 1
            
            var myKey: String!
            
            operation.recordFetchedBlock = { record in
                /*
                 var result = record
                 shoe.recordID = record.recordID
                 shoe.brand = record["brand"] as! String
                 shoe.name = record["name"] as! String
                 shoe.size = record["size"] as! Int
                 
                 newShoes.append(shoe)
                 */
                myKey = record["MY_KEY"] as? String
            }
            
            operation.queryCompletionBlock = { (cursor, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(myKey))
                    }
                }
            }
            database.add(operation)
            
        }
    }
    
    
}

enum DBError: Error {
    case notAvailable(String)
}
