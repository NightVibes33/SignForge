//
//  DeactivateAppOperation.swift
//  AltStore
//
//  Created by Riley Testut on 3/4/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import AltStoreCore
import AltSign
import CoreData

@objc(DeactivateAppOperation)
final class DeactivateAppOperation: ResultOperation<InstalledApp>, @unchecked Sendable
{
    let app: InstalledApp
    let context: OperationContext
    
    init(app: InstalledApp, context: OperationContext)
    {
        self.app = app
        self.context = context
        
        super.init()
    }
    
    override func main()
    {
        super.main()
        
        if let error = self.context.error
        {
            self.finish(.failure(error))
            return
        }
        
        Task {
            do {
                let result = try await self.execute()
                self.finish(.success(result))
            } catch {
                self.finish(.failure(error))
            }
        }
    }
    
    private func execute() async throws -> InstalledApp {
        let backgroundContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let installedApp = await backgroundContext.perform {
            backgroundContext.object(with: self.app.objectID) as! InstalledApp
        }

        try await self.performDeactivate(for: installedApp)
        try await backgroundContext.perform {
            try backgroundContext.save()
        }
        return await DatabaseManager.shared.persistentContainer.viewContext.perform {
            DatabaseManager.shared.persistentContainer.viewContext.object(with: self.app.objectID) as! InstalledApp
        }
    }
    
    @discardableResult
    private func performDeactivate(for installedApp: InstalledApp) async throws -> InstalledApp {
        let appExBundleIds = installedApp.appExtensions.map { $0.resignedBundleIdentifier }
        let allBundleIds = [installedApp.resignedBundleIdentifier] + appExBundleIds

        var removedAny = false
        for bundleId in allBundleIds {
            try await removeProvisioningProfile(bundleId)
            self.progress.completedUnitCount += 1
            removedAny = true
        }
        guard removedAny else {
            throw OperationError.invalidParameters("DeactivateAppOperation: no profiles found to remove")
        }
        installedApp.isActive = false
        return installedApp
    }
    
    private func debugLog(_ text: @autoclosure () -> String) {
        print(text())
    }
    
    private func verboseLog(_ text: @autoclosure () -> String) {
        let isLoggingEnabled = OperationsLoggingControl.getFromDatabase(for: DeactivateAppOperation.self)
        if isLoggingEnabled {
            print(text())
        }
    }
}

