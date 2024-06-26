import LibUV.Loop

open scoped Alloy.C
alloy c include <lean_uv.h>

namespace UV

alloy c section

static void Check_foreach(void* ptr, b_lean_obj_arg f) {
  fatal_st_only("Check");
}

static void Check_finalize(void* ptr) {
  bool is_active = ((lean_uv_check_t*) ptr)->callback != NULL;
  lean_uv_finalize_handle((uv_handle_t*) ptr, is_active);
}

static void check_invoke_callback(uv_check_t* check) {  // Get callback and handler objects
  lean_uv_check_t* luv_check = (lean_uv_check_t*) check;
  lean_object* cb = luv_check->callback;
  lean_inc(cb);
  check_callback_result(luv_check->uv.loop, lean_apply_1(cb, lean_io_mk_world()));
}
end

alloy c opaque_extern_type Check => lean_uv_check_t where
  foreach  => "Check_foreach"
  finalize => "Check_finalize"

alloy c extern "lean_uv_check_init"
def Loop.mkCheck (loop : Loop) : UV.IO Check := {
  lean_uv_check_t* check = checked_malloc(sizeof(lean_uv_check_t));
  uv_check_init(of_loop(loop), &check->uv);
  check->callback = 0;
  lean_object* r = to_lean<Check>(check);
  check->uv.data = r;
  return lean_io_result_mk_ok(r);
}

/--
Start invoking the callback on the loop.
-/
alloy c extern "lean_uv_check_start"
def Check.start (check : @&Check) (callback : UV.IO Unit) : UV.IO Unit := {
  lean_uv_check_t* luv_check = lean_get_external_data(check);
  if (luv_check->callback) {
    lean_dec_ref(luv_check->callback);
  } else {
    uv_check_start(&luv_check->uv, &check_invoke_callback);
  }
  luv_check->callback = callback;
  return lean_io_unit_result_ok();
}

/--
Stop invoking the check handler.
-/
alloy c extern "lean_uv_check_stop"
def Check.stop (check : @&Check) : UV.IO Unit := {
  lean_uv_check_t* luv_check = lean_get_external_data(check);
  if (luv_check->callback) {
    uv_check_stop(&luv_check->uv);
    lean_dec_ref(luv_check->callback);
    luv_check->callback = 0;
  }
  return lean_io_unit_result_ok();
}
