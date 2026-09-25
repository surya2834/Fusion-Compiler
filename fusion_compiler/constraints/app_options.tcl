# Fusion Compiler — application options, grouped by the error they fix.
#
# Open the block first, then:
#   source app_options.tcl
#   fc_fix list
#   fc_fix congestion
#
# One call sets only that group. It does not run place_opt, clock_opt, or route_opt.
# Rerun the stage printed at the end of the call.
# A name this build does not have is printed as SKIP. The rest of the group still runs.
# Check a name with:  report_app_options <name>
#
# Every option below is printed with four lines:
#   Why      the error that makes this option worth turning on
#   When     the stage and the report that show that error
#   Purpose  what the tool does differently after the option is set
#   If off   what you still see if you leave the option at its default

proc fc_app {name value why when purpose if_off} {
  echo "----------------------------------------------------------------"
  echo "OPTION   $name = $value"
  echo "Why      $why"
  echo "When     $when"
  echo "Purpose  $purpose"
  echo "If off   $if_off"
  if {[catch {set_app_options -name $name -value $value} msg]} {
    echo "SKIP     $name : $msg"
    return
  }
  echo "SET      $name"
}

proc fc_fix {problem} {
  switch -- $problem {

    list {
      echo "fc_fix missing_scandef   place_opt stops: no scan DEF"
      echo "fc_fix congestion         overflow in report_congestion"
      echo "fc_fix legality           check_legality overlaps or off-row cells"
      echo "fc_fix setup_place        setup WNS after place_opt, clock still ideal"
      echo "fc_fix transition         max_transition or max_capacitance violators"
      echo "fc_fix area               cell area too high after compile or place_opt"
      echo "fc_fix hold               hold violators on func_fast after CTS or route"
      echo "fc_fix useful_skew        setup still failing after the clock tree exists"
      echo "fc_fix skew               report_clock_timing -type skew above target"
      echo "fc_fix antenna            check_routes -antenna is not clean"
      echo "fc_fix route_drc          opens or shorts left in check_routes"
      echo "fc_fix crosstalk          delta delay on a timing path after route"
      echo "fc_fix tie                undriven tie-high or tie-low pins"
      return
    }

    # ------------------------------------------------------------------
    # place_opt exits before it places anything, because no scan DEF was read.
    # This router has no scan chains, so that stop is not a real scan problem.
    # ------------------------------------------------------------------
    missing_scandef {
      fc_app place.coarse.continue_on_missing_scandef true \
        "Coarse placement refuses to start when read_scan_def was never run." \
        "The first place_opt, when the log says the scan DEF is missing." \
        "Placement continues and treats scan stitching as something you will do later, or not at all." \
        "place_opt stops. No cells are placed, so every later stage has nothing to open."
      echo "Rerun: place_opt"
    }

    # ------------------------------------------------------------------
    # report_congestion shows overflow. Cells are packed tighter than the
    # tracks can route. Utilization can still look fine while overflow is not.
    # 0.55 is looser than the 0.65 already set in 04_placement.tcl.
    # ------------------------------------------------------------------
    congestion {
      fc_app place.coarse.max_density 0.55 \
        "A local window is filled so full that global routing has no free tracks." \
        "After place_opt, when report_congestion overflow is above about 0." \
        "No window is allowed to fill past 55 percent, even if the core average is lower." \
        "The placer packs hotspots solid. Those spots become shorts and opens in route_auto."

      fc_app place.coarse.congestion_driven_max_util 0.70 \
        "The density cap above is global. Congested layers still need their own cap." \
        "Same congestion report, when overflow sits on one metal layer." \
        "In a congested region the placer stops adding cells once local util hits 70 percent." \
        "Cells stay piled on the congested layer and the overflow number barely moves."

      fc_app place.coarse.enhanced_auto_density_control true \
        "A hand-set density can be too tight in one corner and too loose in another." \
        "After one place_opt still shows overflow, before you drop max_density again by hand." \
        "The placer lowers density by itself where the trial route is already full." \
        "Only the fixed 0.55 cap applies. A hotspot the cap missed stays congested."

      fc_app place_opt.place.congestion_effort high \
        "Default effort stops spreading cells once timing looks acceptable." \
        "Overflow is still there after max_density was already lowered." \
        "place_opt spends more passes pulling cells out of the overflow windows." \
        "Runtime is shorter, and the same overflow is still in the next congestion report."

      fc_app place_opt.final_place.effort medium \
        "The last placement pass can pack cells back into a spot you just opened up." \
        "Congestion was clean after coarse place and came back after final_place." \
        "The last pass moves cells less aggressively, so it does not re-pack the hotspot." \
        "final_place pulls cells together again for timing and the overflow returns."

      echo "Rerun: place_opt"
      echo "Read report_congestion again. If overflow is still high, lower core utilization in the floorplan."
    }

    # ------------------------------------------------------------------
    # check_legality lists cells that overlap, sit off the row, or violate
    # a site rule. Routing cannot start on an illegal placement.
    # ------------------------------------------------------------------
    legality {
      fc_app place.legalize.enable_advanced_legalizer true \
        "The basic legalizer cannot shove a cell onto a legal site without a new overlap." \
        "check_legality after place_opt is not clean." \
        "A second legalizer searches harder for a site that keeps the row rules." \
        "The same overlap and off-row cells stay in check_legality, and route_auto inherits them."

      fc_app place.coarse.max_density 0.60 \
        "Illegal cells are often the ones that had no empty site left in a full row." \
        "check_legality fails in the same window where report_congestion shows overflow." \
        "Rows keep empty sites so the legalizer has somewhere to put the cell." \
        "The legalizer has no hole to move the cell into, so the overlap remains."

      echo "Rerun: place_opt"
      echo "Then: check_legality -verbose"
    }

    # ------------------------------------------------------------------
    # Setup WNS after place_opt. The clock in the SDC still has zero delay.
    # These options make placement see clock load before the real tree exists.
    # Useful skew is a later group. Leave CCD off here.
    # ------------------------------------------------------------------
    setup_place {
      fc_app place_opt.flow.clock_aware_placement true \
        "Placement sizes data cells as if the clock pin had no wire load." \
        "report_qor after place_opt, setup WNS negative, and CTS has not been run." \
        "Cell locations take the future clock-pin load into account." \
        "A path that looks closed here opens again as soon as clock_opt adds real clock wires."

      fc_app place_opt.flow.trial_clock_tree true \
        "Clock-aware placement still uses an estimate. It has not built even a temporary tree." \
        "Same setup WNS, and the bad paths are register-to-register rather than input-to-register." \
        "A temporary clock tree is built during place_opt so buffering sees a realistic clock." \
        "The placer keeps underestimating clock delay. The WNS you close is not the WNS after CTS."

      fc_app place_opt.flow.enable_ccd false \
        "Concurrent clock optimization during placement moves edges before any real tree exists." \
        "Always, on the first place_opt. Turn it on only with fc_fix useful_skew, after CTS." \
        "Placement fixes setup by moving data cells and resizing, not by borrowing clock skew." \
        "CCD at this stage invents skew the later clock tree will not keep, and it can add hold violations."

      fc_app place_opt.final_place.effort high \
        "Medium effort stops moving cells while several endpoints are still negative." \
        "WNS improved in initial_opto and got worse again, or stayed negative, at the end of place_opt." \
        "The last placement pass is allowed more moves to pull the failing endpoints in." \
        "Those endpoints stay where the medium pass left them, and the same WNS is in place_qor.rpt."

      fc_app opt.timing.effort high \
        "The sizer gives up on a path once the cost in area or congestion looks high." \
        "report_constraint -all_violators still lists setup on func_slow after place_opt." \
        "Sizing and buffering keep working the setup paths for more iterations." \
        "The worst path is left as it was. Area stays smaller and WNS stays negative."

      fc_app place_opt.flow.optimize_icgs true \
        "A clock-gate enable that is late looks like a data-path setup failure." \
        "The worst path ends at an integrated clock gate, not at a normal register data pin." \
        "place_opt is allowed to resize and move those clock gates." \
        "The clock gates stay at their mapped size and the enable path remains the WNS."

      echo "Rerun: place_opt"
      echo "Read place_qor.rpt on func_slow. Do not judge hold yet."
    }

    # ------------------------------------------------------------------
    # max_transition or max_capacitance in report_constraint -all_violators.
    # A long net or a weak driver. Timing slack can still be positive.
    # ------------------------------------------------------------------
    transition {
      fc_app opt.common.enable_rde high \
        "The violation is electrical, on the transition or the load, not on the slack." \
        "report_constraint lists max_transition or max_capacitance after compile or place_opt." \
        "High rule-based driver effort inserts buffers and upsizes cells until the slew is legal." \
        "The timer keeps reporting the same slew. A later route makes that slew worse, not better."

      fc_app opt.common.max_net_length 1000 \
        "One net runs so far across the core that no single cell can drive the slew." \
        "The violator is a long net in the timing report, often a reset, enable, or high-fanout net." \
        "Optimization breaks that net with buffers once its estimated length passes this limit." \
        "The net stays one piece. Transition fails at the far pins, and route_auto may also congest there."

      fc_app opt.timing.effort high \
        "Transition repair stops early because the sizer is also chasing setup." \
        "A few max_transition violators remain after enable_rde was already high." \
        "More sizing iterations are spent on the remaining electrical violators." \
        "Those last violators stay in the constraint report into CTS and route."

      echo "Rerun: place_opt    or compile_fusion through initial_drc if you are still in compile"
    }

    # ------------------------------------------------------------------
    # report_area after compile or place_opt is larger than the core can hold.
    # This does not fix a timing violation. It asks the tool to spend area.
    # ------------------------------------------------------------------
    area {
      fc_app opt.area.effort high \
        "Mapping and sizing kept a larger cell wherever timing was even slightly easier." \
        "report_area cell area is high, or the floorplan utilization came out above the 0.55 target." \
        "The optimizer swaps in a smaller cell when the slack can afford it." \
        "Area stays at whatever timing-only sizing chose, and the core has less room for routes."

      fc_app opt.timing.effort medium \
        "High timing effort and high area effort fight each other. Timing wins and area does not drop." \
        "You already ran fc_fix area once and report_area barely changed." \
        "Timing effort is pulled back so area recovery is allowed to change cells." \
        "Every resize still prefers the faster cell, and the area number stays where it was."

      echo "Rerun: compile_fusion -to logic_opto    or place_opt"
      echo "If utilization is the real problem, lower it in 02_floorplan.tcl. This option cannot shrink the die."
    }

    # ------------------------------------------------------------------
    # Hold violators on func_fast. Data arrives before the capture clock.
    # Fix this after the clock tree exists. Fixing hold during placement,
    # while the clock delay is still zero, inserts buffers you do not need.
    # ------------------------------------------------------------------
    hold {
      fc_app clock_opt.hold.effort high \
        "The clock tree added delay on some flops and not on others, so short data paths fail hold." \
        "cts_hold.rpt or route_hold.rpt on func_fast lists slack below zero." \
        "clock_opt inserts delay cells on the short data paths and tries harder before it gives up." \
        "Hold stays at the default effort. The same violators are still there after final_opto."

      fc_app refine_opt.hold.effort high \
        "After the clock is routed, clock_opt is no longer the command that owns hold." \
        "Hold showed up in route_hold.rpt, or it came back after route_opt." \
        "The post-route optimizer spends more effort on hold, using the real wire delays." \
        "route_opt spends its effort on setup and leaves the hold violators in place."

      fc_app clock_opt.flow.enable_ccd false \
        "Useful skew that fixed setup can be the reason hold failed." \
        "Hold appeared only after a run that had CCD on." \
        "Clock edges stay where the balanced tree put them, so hold repair uses data-path delay only." \
        "CCD keeps borrowing skew for setup and the hold report gets worse each time you rerun final_opto."

      fc_app place_opt.flow.enable_ccd false \
        "The same skew borrow can also be turned on inside placement." \
        "You are about to rerun place_opt on a block that already has hold violators." \
        "Placement will not add new useful skew on top of the hold problem." \
        "place_opt reintroduces the skew that final_opto just removed, and hold comes back."

      echo "Rerun: clock_opt -from final_opto    or route_opt if the wires already exist"
      echo "Read hold on func_fast. A hold fix can cost setup slack on func_slow."
    }

    # ------------------------------------------------------------------
    # Setup is still negative after a real clock tree exists.
    # CCD moves the launch or capture edge instead of only resizing data cells.
    # It can create new hold violations. Read func_fast after this run.
    # ------------------------------------------------------------------
    useful_skew {
      fc_app clock_opt.flow.enable_ccd true \
        "Data-path sizing cannot close setup without a huge cell, but a later capture clock would." \
        "cts_setup.rpt WNS is still negative after clock_opt final_opto with CCD left off." \
        "The tool postpones the capture clock or prepones the launch clock on the failing endpoints." \
        "Only cell sizing is tried. The path stays negative, or the sizer grows cells until congestion appears."

      fc_app place_opt.flow.enable_ccd true \
        "The same borrow is available if you have to rerun placement after CTS." \
        "You are rerunning place_opt on a block whose clock tree already exists and setup is still open." \
        "Placement and clock edges are adjusted together." \
        "place_opt moves cells under a frozen clock and cannot use the skew that would have closed the path."

      fc_app opt.timing.effort high \
        "CCD alone does not resize the cells on the failing path." \
        "WNS improved with CCD and a handful of endpoints are still negative." \
        "Those remaining endpoints still get buffer and size changes." \
        "The skew moves, the cells stay weak, and the last endpoints stay negative."

      echo "Rerun: clock_opt -from final_opto"
      echo "Then read hold on func_fast. If hold got worse, run: fc_fix hold"
    }

    # ------------------------------------------------------------------
    # report_clock_timing -type skew is above the target in 05_cts.tcl (0.050 ns).
    # Local skew lets two nearby flops differ by less than the whole-tree target.
    # The target number itself is set_clock_tree_options, not an app option.
    # ------------------------------------------------------------------
    skew {
      fc_app cts.compile.enable_local_skew true \
        "One global skew target makes every sink match the farthest sink, which is more than nearby flops need." \
        "cts_skew.rpt global skew is near the target, but a local pair of flops is still far apart." \
        "Clock-tree compile balances sinks that talk to each other more tightly than the global target." \
        "Only the global target is used. A short path between two badly skewed neighbors fails hold."

      fc_app cts.optimize.enable_local_skew true \
        "Compile built the tree. The optimize pass can undo the local balance while it chases setup." \
        "Skew was acceptable after build_clock and grew again during final_opto." \
        "The optimize pass is told to keep the local skew target while it resizes clock cells." \
        "final_opto moves clock cells for setup and the local skew you just built is gone."

      fc_app clock_opt.hold.effort medium \
        "Tightening skew inserts clock cells, and those cells often create hold violations." \
        "You are rebuilding the tree because skew failed, and the last rebuild made hold worse." \
        "Hold is repaired in the same clock_opt run, at medium effort so it does not fight the skew target." \
        "The new tree meets skew and fails hold, and you have to run a second final_opto anyway."

      echo "Also set the number: set_clock_tree_options -target_skew 0.050"
      echo "Rerun: clock_opt -from build_clock -to route_clock"
    }

    # ------------------------------------------------------------------
    # check_routes -antenna. A long metal into a gate collects charge.
    # Hopping breaks the metal onto another layer. A diode is the second choice
    # and needs a real library cell:  set ANTENNA_DIODES <lib_cell>
    # ------------------------------------------------------------------
    antenna {
      fc_app route.detail.antenna true \
        "Detail routing will not look at antenna rules unless this is on." \
        "Before route_auto, or after check_routes -antenna lists violations." \
        "Each long metal into a gate input is checked against the antenna rule during detail route." \
        "The router finishes, and every antenna violation is still there for signoff."

      fc_app route.detail.hop_layers_to_fix_antenna true \
        "The check only reports the violation. Hopping is what changes the metal." \
        "route_antenna.rpt is not empty, and you would rather add a via than add a cell." \
        "The router breaks the charged wire onto a higher layer so the gate sees a shorter segment." \
        "The wire stays on one layer. The same antenna ratio is reported on the next check."

      fc_app route.detail.antenna_fixing_preference layer_hopping \
        "With both hopping and diodes available, the router may insert a diode where a via would do." \
        "Antenna violations remain and you have not set a diode cell, or you want the smaller fix first." \
        "Layer hopping is tried before any diode is added." \
        "The router picks its own order and may add diodes you did not ask for, which costs area and a placement site."

      if {[info exists ::ANTENNA_DIODES] && $::ANTENNA_DIODES ne ""} {
        fc_app route.detail.diode_libcell_names $::ANTENNA_DIODES \
          "Hopping cannot break a wire that has nowhere to jump, usually at the top routing layer." \
          "route_antenna.rpt still has violations after a route that already had hopping on." \
          "The named diode cell is tied to the violating gate input and gives the charge a path off the gate." \
          "Those top-layer violations have no fix, and they fail foundry antenna signoff."

        fc_app route.detail.insert_diodes_during_routing true \
          "Naming the diode does not by itself tell detail route to insert it while it routes." \
          "diode_libcell_names is set and the next check_routes -antenna is still not clean." \
          "Diodes are dropped in during detail route instead of in a later ECO." \
          "The diode cell is known but unused. The antenna violation survives route_auto."
      } else {
        echo "Diode cell is not set. Hopping is on. A violation at the top routing layer needs a diode:"
        echo "  set ANTENNA_DIODES <lib_cell>"
        echo "  fc_fix antenna"
      }
      echo "Rerun: route_auto -max_detail_route_iterations 5"
      echo "Then: check_routes -antenna"
    }

    # ------------------------------------------------------------------
    # check_routes still shows opens or shorts after route_auto.
    # Effort options make the router try harder. The retry count is an
    # argument of route_auto, not an application option.
    # ------------------------------------------------------------------
    route_drc {
      fc_app route.global.effort_level high \
        "Detail route cannot fix a short whose global path was already forced through a full gcell." \
        "route_drc.rpt opens or shorts, and report_congestion after route still shows overflow." \
        "Global routing spends more effort finding a path that is not already full." \
        "Detail route ripps up the same crowded global path and the short comes back."

      fc_app route.detail.drc_convergence_effort_level high \
        "The default detail-route pass gives up while shorts are still dropping." \
        "Opens or shorts fell across iterations and then stopped above zero." \
        "More rip-up and reroute passes are allowed inside one route_auto." \
        "The router stops at the default effort and writes the remaining shorts into route_drc.rpt."

      fc_app route.detail.timing_driven true \
        "A DRC-only reroute will shove a critical net onto a long detour to clear a short." \
        "You are rerunning route to clear DRC, and the last rerun made setup WNS worse." \
        "When two paths can clear the short, the router keeps the one with less delay." \
        "The short disappears and the setup path that was next to it picks up a long detour."

      fc_app route.global.timing_driven true \
        "The detour often starts in global route, before detail route ever sees the net." \
        "Same case: DRC is the goal, and setup got worse on the previous route_auto." \
        "Global route also prefers the lower-delay path when several gcells are open." \
        "Global route picks the empty gcell even when it is the long way around, and detail route cannot fully undo it."

      echo "Rerun: route_auto -max_detail_route_iterations 10"
      echo "If the same shorts remain, the problem is congestion. Run fc_fix congestion and place_opt again."
    }

    # ------------------------------------------------------------------
    # A path that met timing before route fails after route because a neighbor
    # wire adds delay. That extra delay is the delta delay in the timing report.
    # ------------------------------------------------------------------
    crosstalk {
      fc_app route.global.crosstalk_driven true \
        "Two long parallel wires were routed side by side, and the victim net slowed down." \
        "A path in route_setup.rpt has a large delta delay that was not in the pre-route report." \
        "Global route separates aggressor and victim instead of only minimizing length." \
        "The wires stay parallel. The same delta delay is in the next timing report."

      fc_app route.detail.timing_driven true \
        "Global route can space the nets and detail route can still pull them back together to save a track." \
        "crosstalk_driven is already on and the delta delay is still on one net." \
        "Detail route keeps a spacing or a layer change when that choice holds the slack." \
        "Detail route uses the empty track next to the aggressor, and the delta delay returns."

      fc_app time.si_enable_analysis true \
        "Without signal-integrity analysis the timer never computes the delta delay, so route cannot avoid it." \
        "You suspect crosstalk, but the timing report has no delta-delay column at all." \
        "The timer adds the neighbor coupling into the path delay that route_opt reads." \
        "route_opt closes a slack number that ignores coupling. PrimeTime later shows the path failing."

      echo "Rerun: route_opt"
      echo "Compare delta delay in route_setup.rpt before and after."
    }

    # ------------------------------------------------------------------
    # A pin tied to logic 1 or logic 0 has no driver. The netlist check
    # calls it undriven. The tie cell from the library is the driver.
    # ------------------------------------------------------------------
    tie {
      fc_app opt.tie_cell.max_fanout 8 \
        "One tie cell driving every constant pin is a long net and a transition violation." \
        "check_design or report_constraint shows undriven constant pins, or one tie net failing max_transition." \
        "A new tie cell is built once a tie net would fan out to more than 8 pins." \
        "Either the pins stay undriven, or one tie cell drives the whole set and the slew fails."

      fc_app opt.common.max_net_length 500 \
        "Fanout of 8 can still be a long wire if the pins are on opposite sides of the core." \
        "The tie net is legal on fanout and still fails max_transition because of length." \
        "The tie net is split again when its length passes this limit." \
        "The fanout rule is met and the far pins still see a slow edge."

      echo "The tie cells also have to be usable. In the shell, before you rerun:"
      echo "  set_dont_touch \[get_lib_cells */*TIE*\] false"
      echo "  set_attribute \[get_lib_cells */*TIE*\] dont_use false"
      echo "Rerun: place_opt"
    }

    default {
      echo "Unknown group: $problem"
      echo "Run: fc_fix list"
    }
  }
}

echo "Loaded. Run: fc_fix list"
