// Copyright (c) Facebook, Inc. and its affiliates.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the "hack" directory of this source tree.
#![allow(clippy::comparison_chain)]

use std::path::Path;

use hh24_types::Checksum;
use hh24_types::RichChecksum;
use hh24_types::ToplevelSymbolHash;
use nohash_hasher::IntMap;
use nohash_hasher::IntSet;
use relative_path::RelativePath;

pub struct NamingTable {
    path_cache: IntMap<ToplevelSymbolHash, Option<RelativePath>>,
    pub names: crate::Names,
    rich_checksums: IntMap<Checksum, RichChecksum>,
    pub checksum: Checksum,
}

impl NamingTable {
    pub fn new(path: impl AsRef<Path>) -> Self {
        let names = crate::Names::from_file(path).unwrap();
        let checksum = names.get_checksum().unwrap();
        Self {
            path_cache: IntMap::default(),
            names,
            rich_checksums: IntMap::default(),
            checksum,
        }
    }

    pub fn checksum(&self) -> Checksum {
        self.checksum
    }

    /// WARNING: this is currently a costly O(table) operation
    pub fn process_changed_file(
        &mut self,
        path: &RelativePath,
        file_summary: crate::FileSummary,
    ) -> anyhow::Result<(IntSet<ToplevelSymbolHash>, IntSet<ToplevelSymbolHash>)> {
        let mut removed_symbol_hashes = self.names.get_symbol_hashes_for_winners(path)?;
        let mut changed_symbol_hashes = IntSet::default();

        for (symbol_hash, decl_hash) in file_summary.decl_hashes() {
            removed_symbol_hashes.remove(&symbol_hash);

            if let Some(old_decl_hash) = self.names.get_decl_hash(symbol_hash)? {
                if let Some(old_filename) = self.names.get_path_by_symbol_hash(symbol_hash)? {
                    if old_filename.path_str() == path.path_str() {
                        // we are dealing with the same symbol from the same file
                        // add it back to checksum
                        self.checksum.addremove(symbol_hash, decl_hash, path);
                    } else if old_filename.path_str() > path.path_str() {
                        // symbol changed is alphabetically first filename
                        changed_symbol_hashes.insert(symbol_hash);
                        self.path_cache.remove(&symbol_hash);
                        self.checksum
                            .addremove(symbol_hash, old_decl_hash, &old_filename);
                        self.checksum.addremove(symbol_hash, decl_hash, path);
                    }
                }
            } else {
                // No collision
                self.checksum.addremove(symbol_hash, decl_hash, path);
                changed_symbol_hashes.insert(symbol_hash);
                self.path_cache.remove(&symbol_hash);
            }
        }

        self.remove_file(path)?;
        self.names.save_file_summary(path, &file_summary)?;

        Ok((changed_symbol_hashes, removed_symbol_hashes))
    }

    /// WARNING: this is currently a costly O(table) operation
    pub fn remove_file(
        &mut self,
        path: &RelativePath,
    ) -> anyhow::Result<IntSet<ToplevelSymbolHash>> {
        let symbol_hashes = self.names.get_symbol_hashes_for_winners(path)?;
        let overflow_symbol_hashes = self.names.get_symbol_hashes_for_losers(path)?;
        let affected_symbol_hashes: IntSet<_> = symbol_hashes
            .union(&overflow_symbol_hashes)
            .copied()
            .collect();
        let mut changed_symbol_hashes = IntSet::default();
        // combined_hashes is the forward naming table for this file BEFORE the change
        let combined_hashes = self.names.get_symbol_and_decl_hashes_for_winners(path)?;

        // remove symbols from naming table
        for &symbol_hash in &affected_symbol_hashes {
            let old_filename = self.names.get_path_by_symbol_hash(symbol_hash)?;
            self.names.remove_symbol(symbol_hash, path)?;
            let new_filename = self.names.get_path_by_symbol_hash(symbol_hash)?;

            if new_filename != old_filename {
                if let Some(decl_hash) = self.names.get_decl_hash(symbol_hash)? {
                    // an inferior symbol has been promoted. We'll add this newly-promoted one.
                    self.checksum
                        .addremove(symbol_hash, decl_hash, new_filename.as_ref().unwrap());
                }
            }

            if old_filename != self.names.get_path_by_symbol_hash(symbol_hash)? {
                changed_symbol_hashes.insert(symbol_hash);
            }

            self.path_cache.remove(&symbol_hash);
        }

        self.names.delete(path)?;

        // Remove combined hashes from checksum (i.e. all symbols in the file before the change)
        for (symbol_hash, decl_hash, _file_info_id) in combined_hashes {
            self.checksum.addremove(symbol_hash, decl_hash, path);
        }

        Ok(changed_symbol_hashes)
    }

    /// Based on the current checksum value, creates a RichChecksum structure for it,
    /// stores it in the mutable rich_checksums history, and returns it.
    pub fn create_rich_checksum(&mut self, example_symbol: &str) -> RichChecksum {
        let rich_checksum = RichChecksum {
            checksum: self.checksum,
            timestamp: hh24_types::Timestamp::now(),
            example_symbol: example_symbol.to_owned(),
        };
        self.rich_checksums
            .insert(self.checksum, rich_checksum.clone());
        rich_checksum
    }

    pub fn get_rich_checksum(
        &self,
        checksum: hh24_types::Checksum,
    ) -> Option<hh24_types::RichChecksum> {
        self.rich_checksums.get(&checksum).map(|x| x.to_owned())
    }

    pub fn get_and_cache_path_by_symbol_hash(
        &mut self,
        symbol_hash: ToplevelSymbolHash,
    ) -> anyhow::Result<Option<RelativePath>> {
        if let Some(path_opt) = self.path_cache.get(&symbol_hash) {
            return Ok(path_opt.clone());
        }
        let path_opt = self.names.get_path_by_symbol_hash(symbol_hash)?;
        self.path_cache.insert(symbol_hash, path_opt.clone());
        Ok(path_opt)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[allow(clippy::assertions_on_constants)]
    fn test_get_non_existent_const() {
        let names = crate::Names::new_in_memory().unwrap();
        let result = names
            .get_filename(ToplevelSymbolHash::from_const("\\Foo"))
            .unwrap();

        match result {
            Some((path, _)) => assert!(false, "Unexpected path: {:?}", path),
            None => assert!(true),
        }
    }
}
