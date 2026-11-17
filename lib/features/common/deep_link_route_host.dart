// Copyright (C) 2026 1-leo

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/deep_link.dart';
import '../../state/deep_link.dart';

/// Applies the deep link a route was matched on (URL → state).
///
/// go_router does the matching; this widget turns the matched URL into the app
/// state the UI already watches **once, when the route is mounted**. That is
/// exactly when a deep link lands: a cold-start launch, a typed URL, a shared
/// link, or the browser going forward onto one. It runs on every deep-linkable
/// route (the map home's `at=` view, `/search`, `/place/…`, `/directions`), so
/// such a URL runs the same providers a tap would.
///
/// It deliberately does not re-apply on later builds: once a route is open, the
/// app state is the source of truth (the outbound mirror writes the URL), and a
/// sub-screen editing an endpoint must not be reverted by a stale URL.
class DeepLinkRouteHost extends ConsumerStatefulWidget {
  const DeepLinkRouteHost({required this.link, required this.child, super.key});

  /// The link to apply, or `null` when the current URL is not this route (the
  /// route is not the top of the stack): nothing is applied then.
  final DeepLink? link;
  final Widget child;

  @override
  ConsumerState<DeepLinkRouteHost> createState() => _DeepLinkRouteHostState();
}

class _DeepLinkRouteHostState extends ConsumerState<DeepLinkRouteHost> {
  @override
  void initState() {
    super.initState();
    final DeepLink? link = widget.link;
    if (link == null) {
      return;
    }
    // Deferred: applying a link writes providers, which is not allowed from a
    // widget life-cycle (initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(deepLinkControllerProvider.notifier).apply(link));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
