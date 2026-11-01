export declare function editDistanceIsOne(a: string, b: string): boolean;
export declare function lookalikeReason(a: string, b: string): 'same_local_part' | 'one_character_apart' | null;
export declare function findLookalikes(users: { id: string; identifier: string }[]): Map<string, string[]>;
