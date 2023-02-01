//
//  RatingModel.swift
//  AddModelToARKit
//
//  Created by VIJAY M on 31/01/23.
//

import Foundation

// MARK: - RatingModel
struct RatingModel: Codable {
    let idlySambar, naanChanna, chappathi: Chappathi

    enum CodingKeys: String, CodingKey {
        case idlySambar = "IdlySambar"
        case naanChanna
        case chappathi = "Chappathi"
    }
}

// MARK: - Chappathi
struct Chappathi: Codable {
    let rating: String

    enum CodingKeys: String, CodingKey {
        case rating = "Rating"
    }
}
