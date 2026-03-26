import AppIntents
import SwiftData

struct BlockedProfileEntity: AppEntity, Identifiable {
  let id: UUID
  let name: String

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "Profile"
  )

  static var defaultQuery = BlockedProfilesQuery()

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}

struct BlockedProfilesQuery: EntityQuery {
  @Dependency(key: "ModelContainer")
  private var modelContainer: ModelContainer

  @MainActor
  private var modelContext: ModelContext {
    return modelContainer.mainContext
  }

  @MainActor
  func entities(for identifiers: [UUID]) async throws
    -> [BlockedProfileEntity]
  {
    let results = try modelContext.fetch(
      FetchDescriptor<BlockedProfiles>(
        predicate: #Predicate { identifiers.contains($0.id) }
      )
    )
    return results.map { BlockedProfileEntity(id: $0.id, name: $0.name) }
  }

  @MainActor
  func suggestedEntities() async throws -> [BlockedProfileEntity] {
    let results = try modelContext.fetch(
      FetchDescriptor<BlockedProfiles>(sortBy: [.init(\.name)])
    )
    return results.map { BlockedProfileEntity(id: $0.id, name: $0.name) }
  }

  func defaultResult() async -> BlockedProfileEntity? {
    try? await suggestedEntities().first
  }
}
