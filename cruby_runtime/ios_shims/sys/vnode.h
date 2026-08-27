#pragma once

// CRuby includes <sys/vnode.h> for Darwin path normalization, but the public
// iOS SDK no longer ships that private macOS header. dir.c does not consume a
// declaration from it; the public <sys/attr.h> and <sys/mount.h> APIs provide
// everything used by this build.
