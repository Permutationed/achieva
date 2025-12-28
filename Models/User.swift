//
//  User.swift
//  Achieva
//
//  Simple user model
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let name: String
    let username: String
}
