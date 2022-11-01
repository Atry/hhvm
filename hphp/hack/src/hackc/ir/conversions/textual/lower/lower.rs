// Copyright (c) Facebook, Inc. and its affiliates.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the "hack" directory of this source tree.

use std::sync::Arc;

use ir::Func;
use ir::FuncBuilder;
use ir::StringInterner;
use log::trace;

pub(crate) fn lower<'a>(func: Func<'a>, strings: Arc<StringInterner>) -> Func<'a> {
    trace!(
        "Before Lower: {}",
        ir::print::DisplayFunc(&func, true, &strings)
    );
    let mut builder = FuncBuilder::with_func(func, Arc::clone(&strings));

    // Simplify various Instrs.
    super::instrs::lower_instrs(&mut builder);

    let mut func = builder.finish();
    ir::passes::split_critical_edges(&mut func, true);

    ir::passes::clean::run(&mut func);

    trace!(
        "After Lower: {}",
        ir::print::DisplayFunc(&func, true, &strings)
    );
    func
}
