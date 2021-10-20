// Copyright (c) Facebook, Inc. and its affiliates.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the "hack" directory of this source tree.
//
// @generated SignedSource<<a725c5e0abc5098c343add3ed09427be>>
//
// To regenerate this file, run:
//   hphp/hack/src/oxidized_regen.sh

use arena_trait::TrivialDrop;
use eq_modulo_pos::EqModuloPos;
use no_pos_hash::NoPosHash;
use ocamlrep_derive::FromOcamlRepIn;
use ocamlrep_derive::ToOcamlRep;
use serde::Deserialize;
use serde::Serialize;

#[allow(unused_imports)]
use crate::*;

#[derive(
    Clone,
    Copy,
    Debug,
    Deserialize,
    Eq,
    EqModuloPos,
    FromOcamlRepIn,
    Hash,
    NoPosHash,
    Ord,
    PartialEq,
    PartialOrd,
    Serialize,
    ToOcamlRep
)]
#[repr(C)]
pub enum Pos<'a> {
    #[serde(deserialize_with = "arena_deserializer::arena", borrow)]
    Qpos(&'a pos::Pos<'a>),
    #[serde(deserialize_with = "arena_deserializer::arena", borrow)]
    QclassishStart(&'a str),
}
impl<'a> TrivialDrop for Pos<'a> {}
arena_deserializer::impl_deserialize_in_arena!(Pos<'arena>);

#[derive(
    Clone,
    Debug,
    Deserialize,
    Eq,
    EqModuloPos,
    FromOcamlRepIn,
    Hash,
    NoPosHash,
    Ord,
    PartialEq,
    PartialOrd,
    Serialize,
    ToOcamlRep
)]
#[repr(C)]
pub struct Quickfix<'a> {
    #[serde(deserialize_with = "arena_deserializer::arena", borrow)]
    pub title: &'a str,
    #[serde(deserialize_with = "arena_deserializer::arena", borrow)]
    pub new_text: &'a str,
    #[serde(deserialize_with = "arena_deserializer::arena", borrow)]
    pub pos: Pos<'a>,
}
impl<'a> TrivialDrop for Quickfix<'a> {}
arena_deserializer::impl_deserialize_in_arena!(Quickfix<'arena>);