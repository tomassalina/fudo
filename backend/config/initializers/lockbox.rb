# Master keys for field-level encryption (Lockbox) and blind indexing
# (blind_index), used by Consumer#dni. See backend/.env for how these are
# generated in development — see the comment there for the cross-workstream
# note on replacing them for anything beyond local dev/demo.
Lockbox.master_key = ENV["LOCKBOX_MASTER_KEY"]
BlindIndex.master_key = ENV["BLIND_INDEX_MASTER_KEY"]
