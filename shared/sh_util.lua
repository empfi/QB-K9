-- Shared utility functions
function RelationshipBetweenGroups(group1, group2, relationship)
    SetRelationshipBetweenGroups(relationship, GetHashKey(group1), GetHashKey(group2))
    SetRelationshipBetweenGroups(relationship, GetHashKey(group2), GetHashKey(group1))
end