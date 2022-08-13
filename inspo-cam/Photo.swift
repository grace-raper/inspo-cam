//
//  Photo.swift
//  inspo-cam
//
//  Created by Grace Raper on 8/13/22.
//

import Foundation

//  MARK: Class Camera Service, handles setup of AVFoundation needed for a basic camera app.
public struct Photo: Identifiable, Equatable {
//    The ID of the captured photo
    public var id: String
//    Data representation of the captured photo
    public var originalData: Data
    
    public init(id: String = UUID().uuidString, originalData: Data) {
        self.id = id
        self.originalData = originalData
    }
}
