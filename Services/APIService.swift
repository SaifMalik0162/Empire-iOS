//
//  APIService.swift
//  Empire
//
//  Deprecated: Replaced by Supabase services.
//  This remains to avoid compile errors during migration.
//

import Foundation

@available(*, deprecated, message: "Use SupabaseAuthService, SupabaseCarsService, and SupabaseMeetsService instead.")
final class APIService {
    static let shared = APIService()
    private init() {}
}
