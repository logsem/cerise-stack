From cap_machine Require Export lang.
From iris.base_logic Require Export invariants gen_heap.
From iris.program_logic Require Export weakestpre lifting.
From iris.proofmode Require Import tactics.
From iris.algebra Require Import frac.

(* CMRΑ for memory *)
Class memG Σ := MemG {
  mem_invG : invG Σ;
  mem_gen_memG :> gen_heapG Addr Word Σ; }.

(* CMRA for registers *)
Class regG Σ := RegG {
  reg_invG : invG Σ;
  reg_gen_regG :> gen_heapG RegName Word Σ; }.


(* invariants for memory, and a state interpretation for (mem,reg) *)
Instance memG_irisG `{memG Σ, regG Σ} : irisG cap_lang Σ := {
  iris_invG := mem_invG;
  state_interp σ κs _ := ((gen_heap_ctx σ.1) ∗ (gen_heap_ctx σ.2))%I;
  fork_post _ := True%I;
}.
Global Opaque iris_invG.

(* Points to predicates *)
Notation "r ↦ᵣ{ q } w" := (mapsto (L:=RegName) (V:=Word) r q w)
  (at level 20, q at level 50, format "r  ↦ᵣ{ q }  w") : bi_scope.
Notation "r ↦ᵣ w" := (mapsto (L:=RegName) (V:=Word) r 1 w) (at level 20) : bi_scope.

Notation "a ↦ₐ { q } w" := (mapsto (L:=Addr) (V:=Word) a q w)
  (at level 20, q at level 50, format "a  ↦ₐ { q }  w") : bi_scope.
Notation "a ↦ₐ w" := (mapsto (L:=Addr) (V:=Word) a 1 w) (at level 20) : bi_scope.

(* temporary and permanent invariants *)
Inductive inv_kind := T | P. 
Definition logN : namespace := nroot .@ "logN".

Definition inv_cap `{memG Σ, regG Σ, inG Σ fracR} (t : inv_kind) iP (ι : namespace) (γ : gname) :=
  match t with
  | T => inv ι (iP ∨ (own γ 1%Qp))%I
  | P => inv ι iP
  end. 

Section cap_lang_rules.
  Context `{memG Σ, regG Σ}.
  Implicit Types P Q : iProp Σ.
  Implicit Types σ : ExecConf.
  Implicit Types c : cap_lang.expr. 
  Implicit Types e : option Addr.
  Implicit Types a b : Addr.
  Implicit Types r : RegName.
  Implicit Types v : cap_lang.val. 
  Implicit Types w : Word.
  Implicit Types reg : gmap RegName Word.
  Implicit Types ms : gmap Addr Word. 


  Lemma locate_ne_reg reg r1 r2 w w' :
    r1 ≠ r2 → reg !r! r1 = w → <[r2:=w']> reg !r! r1 = w.
  Proof.
    intros. rewrite /RegLocate.
    rewrite lookup_partial_alter_ne; eauto.
  Qed.

  Lemma locate_ne_mem mem a1 a2 w w' :
    a1 ≠ a2 → mem !m! a1 = w → <[a2:=w']> mem !m! a1 = w.
  Proof.
    intros. rewrite /MemLocate.
    rewrite lookup_partial_alter_ne; eauto.
  Qed. 

  Ltac inv_head_step :=
    repeat match goal with
           | _ => progress simplify_map_eq/= (* simplify memory stuff *)
           | H : to_val _ = Some _ |- _ => apply of_to_val in H
           | H : _ = of_val ?v |- _ =>
             is_var v; destruct v; first[discriminate H|injection H as H]
           | H : prim_step ?e _ _ _ _ _ |- _ =>
             try (is_var e; fail 1); (* inversion yields many goals if [e] is a variable *)
             (*    and can thus better be avoided. *)
             let φ := fresh "φ" in 
             inversion H as [| φ]; subst φ; clear H
           end.

  Ltac option_locate_mr m r :=
    repeat match goal with
    | H : m !! ?a = Some ?w |- _ => let Ha := fresh "H"a in
        assert (m !m! a = w) as Ha; [ by (unfold MemLocate; rewrite H) | clear H]
    | H : r !! ?a = Some ?w |- _ => let Ha := fresh "H"a in
        assert (r !r! a = w) as Ha; [ by (unfold RegLocate; rewrite H) | clear H]
           end.

  Ltac inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep Hpc_new1 :=
    match goal with
    | H : cap_lang.prim_step Executable (r, m) _ ?e1 ?σ2 _ |- _ =>
      let e0 := fresh "e" in
      let σ := fresh "σ" in
      let o := fresh "o" in
      let e' := fresh "e'" in
      let σ' := fresh "σ'" in
      let Hstep' := fresh "Hstep'" in
      let He0 := fresh "H"e0 in
      let Ho := fresh "H"o in
      let He' := fresh "H"e' in
      let Hσ' := fresh "H"σ' in
      let Hefs := fresh "Hefs" in
      let φ0 := fresh "φ" in
      let p0 := fresh "p" in
      let g0 := fresh "g" in
      let b0 := fresh "b" in
      let e2 := fresh "e" in
      let a0 := fresh "a" in
      let i := fresh "i" in
      let c0 := fresh "c" in
      let HregPC := fresh "HregPC" in
      let Hi := fresh "H"i in
      let Hexec := fresh "Hexec" in 
      inversion H as [e0 σ o e' σ' Hstep' He0 Ho He' Hσ' Hefs];
      inversion Hstep' as [φ0 | φ0 p0 g0 b0 e2 a0 i c0 HregPC ? Hi Hexec];
        (simpl in *; try congruence );
      subst e1 σ2 φ0 σ' e' o σ; try subst c0; simpl in *;
      try (rewrite HPC in HregPC;
           inversion HregPC;
           repeat match goal with
                  | H : _ = p0 |- _ => destruct H
                  | H : _ = g0 |- _ => destruct H
                  | H : _ = b0 |- _ => destruct H
                  | H : _ = e2 |- _ => destruct H
                  | H : _ = a0 |- _ => destruct H
                  end ; destruct Hi ; clear HregPC ;
           rewrite Hpc_a Hinstr /= ;
           rewrite Hpc_a Hinstr in Hstep)
    end. 


 (* --------------------------------------------------------------------------------- *)
 (* ----------------------------------- FAIL RULES ---------------------------------- *)

  Lemma wp_notCorrectPC:
    forall pc_p pc_g pc_b pc_e pc_a,
      ~ isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->
      {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a) }}}
        Executable
        {{{ RET FailedV; True }}}.
  Proof.
    intros until 0. intros Hnpc.
    iIntros (ϕ) "HPC Hϕ".
    iApply wp_lift_step_fupd; eauto.
    iIntros (σ1 l1 l2 n) "Hσ1 /="; destruct σ1; simpl;
    iDestruct "Hσ1" as "[Hr Hm]".
    iDestruct (@gen_heap_valid with "Hr HPC") as %?.
    option_locate_mr m r.
    rewrite -HPC in Hnpc.
    iApply fupd_frame_l. 
    iSplit.
    + rewrite /reducible.
      iExists [], (Failed : cap_lang.expr), (r,m), [].
      iPureIntro.
      constructor.
      apply (step_exec_fail (r,m)); eauto.
    + iMod (fupd_intro_mask' ⊤) as "H"; eauto.
      iModIntro. 
      iIntros (e1 σ2 efs Hstep).
      inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
      iFrame. iModIntro. iNext.
      iApply fupd_frame_l. iFrame.
      iApply wp_value. iApply "Hϕ".
      auto.
  Qed.
  
   Lemma wp_load_fail1 r1 r2 pc_p pc_g pc_b pc_e pc_a w p g b e a :
    cap_lang.decode w = Load r1 r2 →

    isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ∧
     (readAllowed p = false ∨ withinBounds ((p, g), b, e, a) = false) →

    {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
           ∗ pc_a ↦ₐ w
           ∗ r2 ↦ᵣ inr ((p,g),b,e,a) }}}
      Executable
    {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr [Hvpc [Hnra | Hnwb]];
     (iIntros (φ) "(HPC & Hpc_a & Hr2) Hφ";
       iApply wp_lift_step_fupd; eauto;
       iIntros (σ1 l1 l2 n) "Hσ1 /="; destruct σ1; simpl;
       iDestruct "Hσ1" as "[Hr Hm]";
       iDestruct (@gen_heap_valid with "Hr HPC") as %?;
       iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
       iDestruct (@gen_heap_valid with "Hr Hr2") as %?;
       option_locate_mr m r).
     - iApply fupd_frame_l. 
       iSplit.
       + rewrite /reducible.
         iExists [], Failed, (r,m), [].
         iPureIntro.
         constructor.
         apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Load r1 r2)
                                (Failed,_));
           eauto; simpl; try congruence. 
           by rewrite Hr2 Hnra /=.
       + iMod (fupd_intro_mask' ⊤) as "H"; eauto.
         iModIntro. 
         iIntros (e1 σ2 efs Hstep).
         inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
         rewrite Hr2 Hnra /=.
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.
         iApply wp_value. by iApply "Hφ".
     - simpl in *. 
       iApply fupd_frame_l. 
       iSplit.
       + rewrite /reducible.
         iExists [], Failed, (r,m), [].
         iPureIntro.
         constructor.
         apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Load r1 r2)
                                (Failed,_));
           eauto; simpl; try congruence.
           by rewrite Hr2 Hnwb andb_false_r. 
       + iMod (fupd_intro_mask' ⊤) as "H"; eauto.
         iModIntro. 
         iIntros (e1 σ2 efs Hstep).
         inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
         rewrite Hr2 Hnwb andb_false_r. 
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.
         iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_load_fail2 r1 r2 pc_p pc_g pc_b pc_e pc_a w n:
    cap_lang.decode w = Load r1 r2 →

    isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →

    {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
           ∗ pc_a ↦ₐ w
           ∗ r2 ↦ᵣ inl n }}}
      Executable
    {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc.
     iIntros (φ) "(HPC & Hpc_a & Hr2) Hφ".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hr HPC") as %?;
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
     iDestruct (@gen_heap_valid with "Hr Hr2") as %?;
     option_locate_mr m r.
     iApply fupd_frame_l. iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r,m), [].
       iPureIntro.
       constructor.
       eapply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Load r1 r2)
                              (Failed,_));
         eauto; simpl; try congruence.
         by rewrite Hr2.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hr2 /=.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.
       iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_store_fail1 dst src pc_p pc_g pc_b pc_e pc_a w p g b e a :
     cap_lang.decode w = Store dst src →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->
     (writeAllowed p = false ∨ withinBounds ((p, g), b, e, a) = false) →

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inr ((p,g),b,e,a) }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc HnwaHnwb;
     (iIntros (φ) "(HPC & Hpc_a & Hdst) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n) "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l. 
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r,m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Store dst src)
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. destruct HnwaHnwb as [Hnwa | Hnwb].
       + rewrite Hnwa; simpl; auto.
         destruct src; auto.
       + simpl in Hnwb. rewrite Hnwb.
         rewrite andb_comm; simpl; auto.
         destruct src; auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. destruct HnwaHnwb as [Hnwa | Hnwb].
       + rewrite Hnwa; simpl. destruct src; simpl.
         * iFrame. iModIntro. iNext.
           iApply fupd_frame_l. iFrame.         
           iApply wp_value. by iApply "Hφ".
         * iFrame. iModIntro. iNext.
           iApply fupd_frame_l. iFrame.         
           iApply wp_value. by iApply "Hφ".
       + simpl in Hnwb. rewrite Hnwb.
         rewrite andb_comm; simpl.
         destruct src; simpl.
         * iFrame. iModIntro. iNext.
           iApply fupd_frame_l. iFrame.
           iApply wp_value. by iApply "Hφ".
         * iFrame. iModIntro. iNext.
           iApply fupd_frame_l. iFrame.
           iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_store_fail2 dst src pc_p pc_g pc_b pc_e pc_a w n:
     cap_lang.decode w = Store dst src →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inl n}}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc.
     iIntros (φ) "(HPC & Hpc_a & Hdst) Hφ".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hr HPC") as %?;
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
     iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
     option_locate_mr m r.
     iApply fupd_frame_l. iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r,m), [].
       iPureIntro.
       constructor.
       eapply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Store dst src)
                              (Failed,_));
         eauto; simpl; try congruence.
         destruct src; simpl; by rewrite Hdst.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst /=.
       destruct src; simpl.
       + iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.
         iApply wp_value. by iApply "Hφ".
       + iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.
         iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_store_fail3 dst src pc_p pc_g pc_b pc_e pc_a w p g b e a p' g' b' e' a':
     cap_lang.decode w = Store dst (inr src) →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->
     writeAllowed p = true ->
     withinBounds ((p, g), b, e, a) = true →
     isLocal g' = true ->
     p <> RWLX ->
     p <> RWL ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inr ((p,g),b,e,a)
            ∗ src ↦ᵣ inr ((p',g'),b',e',a') }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc Hwa Hwb Hloc Hnrwlx Hnrwl;
     (iIntros (φ) "(HPC & Hpc_a & Hdst & Hsrc) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n) "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      iDestruct (@gen_heap_valid with "Hr Hsrc") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r,m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Store dst (inr src))
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. rewrite Hwa. simpl in Hwb. rewrite Hwb. simpl.
       rewrite Hsrc. rewrite Hloc.
       destruct p; try congruence.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. rewrite Hwa. simpl in Hwb. rewrite Hwb. simpl.
       rewrite Hsrc. rewrite Hloc.
       assert (X: match p with
                    | RWL | RWLX =>
                        updatePC (update_mem (r, m) a (inr (p', g', b', e', a')))
                    | _ => (Failed, (r, m))
                    end = (Failed, (r, m))) by (destruct p; congruence).
       repeat rewrite X.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.
       iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_lea_fail1 dst pc_p pc_g pc_b pc_e pc_a w p g b e a n:
     cap_lang.decode w = Lea dst (inl n) →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->
     (p = E \/ (a + n)%a = None) ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inr ((p,g),b,e,a) }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc HpHa;
     (iIntros (φ) "(HPC & Hpc_a & Hdst) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r,m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Lea dst (inl n))
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. destruct (perm_eq_dec p E).
       + subst p; auto.
       + destruct HpHa as [Hp | Ha]; try congruence.
         rewrite Ha. destruct p; auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. assert (X:match p with
                              | E => (Failed, (r, m))
                              | _ =>
                                match (a + n)%a with
                                | Some a' =>
                                  updatePC (update_reg (r, m) dst (inr (p, g, b, e, a')))
                                | None => (Failed, (r, m))
                                end
                              end = (Failed, (r, m))).
       { destruct (perm_eq_dec p E).
         - subst p; auto.
         - destruct HpHa as [Hp | Ha]; try congruence.
           rewrite Ha. destruct p; auto. }
       repeat rewrite X.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.         
       iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_lea_fail2 dst src pc_p pc_g pc_b pc_e pc_a w n:
     cap_lang.decode w = Lea dst src →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inl n}}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc.
     iIntros (φ) "(HPC & Hpc_a & Hdst) Hφ".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hr HPC") as %?;
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
     iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
     option_locate_mr m r.
     iApply fupd_frame_l. iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r,m), [].
       iPureIntro.
       constructor.
       eapply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Lea dst src)
                              (Failed,_));
         eauto; simpl; try congruence.
         destruct src; simpl; by rewrite Hdst.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst /=.
       destruct src; simpl.
       + iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.
         iApply wp_value. by iApply "Hφ".
       + iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.
         iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_lea_fail3 dst pc_p pc_g pc_b pc_e pc_a w p g b e a rg:
     cap_lang.decode w = Lea dst (inr rg) →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->
     p = E ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inr ((p,g),b,e,a) }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc Hp;
     (iIntros (φ) "(HPC & Hpc_a & Hdst) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r, m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Lea dst (inr rg))
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. subst p; auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. subst p.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.         
       iApply wp_value. by iApply "Hφ".
   Qed.
   
   Lemma wp_lea_fail4 dst pc_p pc_g pc_b pc_e pc_a w p g b e a rg n:
     cap_lang.decode w = Lea dst (inr rg) →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->
     p <> E ->
     (a + n)%a = None ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inr ((p,g),b,e,a)
            ∗ rg ↦ᵣ inl n }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc Hp Ha;
     (iIntros (φ) "(HPC & Hpc_a & Hdst & Hrg) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      iDestruct (@gen_heap_valid with "Hr Hrg") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r, m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Lea dst (inr rg))
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. rewrite Hrg. rewrite Ha.
       destruct p; auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. rewrite Hrg. rewrite Ha.
       assert (X: match p with | O | _ => (Failed, (r, m)) end = (Failed, (r, m))) by (destruct p; auto).
       rewrite X.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.         
       iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_lea_fail5 dst pc_p pc_g pc_b pc_e pc_a w p g b e a rg x:
     cap_lang.decode w = Lea dst (inr rg) →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->
     p <> E ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inr ((p,g),b,e,a)
            ∗ rg ↦ᵣ inr x }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc Hp;
     (iIntros (φ) "(HPC & Hpc_a & Hdst & Hrg) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      iDestruct (@gen_heap_valid with "Hr Hrg") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r, m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Lea dst (inr rg))
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. rewrite Hrg.
       destruct p; auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. rewrite Hrg.
       assert (X: match p with | O | _ => (Failed, (r, m)) end = (Failed, (r, m))) by (destruct p; auto).
       rewrite X.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.         
       iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_restrict_fail1 dst src pc_p pc_g pc_b pc_e pc_a w n:
     cap_lang.decode w = Restrict dst src →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inl n }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc;
     (iIntros (φ) "(HPC & Hpc_a & Hdst) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r, m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Restrict dst src)
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. destruct src; auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. 
       assert (X: match src with | inl _ | _ => (Failed, (r, m)) end = (Failed, (r, m))) by (destruct src; auto).
       rewrite X.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.         
       iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_restrict_fail2 dst src pc_p pc_g pc_b pc_e pc_a w permPair b e a x:
     cap_lang.decode w = Restrict dst (inr src) →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ dst ↦ᵣ inr (permPair, b, e, a)
            ∗ src ↦ᵣ inr x }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc;
     (iIntros (φ) "(HPC & Hpc_a & Hdst & Hsrc) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hdst") as %?;
      iDestruct (@gen_heap_valid with "Hr Hsrc") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r, m), [].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Restrict dst (inr src))
                              (Failed,_));
         eauto; simpl; try congruence.
       rewrite Hdst. rewrite Hsrc. auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst. rewrite Hsrc.
       iFrame. iModIntro. iNext.
       iApply fupd_frame_l. iFrame.         
       iApply wp_value. by iApply "Hφ".
   Qed.

   Lemma wp_add_sub_lt_fail1 dst r1 pc_p pc_g pc_b pc_e pc_a w x y:
     cap_lang.decode w = cap_lang.Add dst (inr r1) y \/ cap_lang.decode w = Sub dst (inr r1) y \/ cap_lang.decode w = Lt dst (inr r1) y →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ r1 ↦ᵣ inr x }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc;
     (iIntros (φ) "(HPC & Hpc_a & Hr1) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hr1") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r, m), [].
       iPureIntro.
       constructor.
       destruct Hinstr as [Hinstr | [Hinstr | Hinstr]].
       + apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (cap_lang.Add dst (inr r1) y)
                              (Failed,_));
         eauto; simpl; try congruence.
         rewrite Hr1. destruct y; auto.
       + apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Sub dst (inr r1) y)
                              (Failed,_));
         eauto; simpl; try congruence.
         rewrite Hr1. destruct y; auto.
       + apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Lt dst (inr r1) y)
                              (Failed,_));
         eauto; simpl; try congruence.
         rewrite Hr1. destruct y; auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep). destruct Hinstr as [Hinstr | [Hinstr | Hinstr]];
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       + rewrite Hr1. assert (X: match y with | inl _ | _ => (Failed, (r, m)) end = (Failed, (r, m))) by (destruct y; auto).
         rewrite X.
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.         
         iApply wp_value; by iApply "Hφ".
       + rewrite Hr1. assert (X: match y with | inl _ | _ => (Failed, (r, m)) end = (Failed, (r, m))) by (destruct y; auto).
         rewrite X.
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.         
         iApply wp_value; by iApply "Hφ".
       + rewrite Hr1. assert (X: match y with | inl _ | _ => (Failed, (r, m)) end = (Failed, (r, m))) by (destruct y; auto).
         rewrite X.
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.         
         iApply wp_value; by iApply "Hφ".
   Qed.

   Lemma wp_add_sub_lt_fail2 dst r2 pc_p pc_g pc_b pc_e pc_a w x y:
     cap_lang.decode w = cap_lang.Add dst x (inr r2) \/ cap_lang.decode w = Sub dst x (inr r2) \/ cap_lang.decode w = Lt dst x (inr r2) →

     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) ->

     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
            ∗ pc_a ↦ₐ w
            ∗ r2 ↦ᵣ inr y }}}
       Executable
       {{{ RET FailedV; True }}}.
   Proof.
     intros Hinstr Hvpc;
     (iIntros (φ) "(HPC & Hpc_a & Hr2) Hφ";
      iApply wp_lift_step_fupd; eauto;
      iIntros (σ1 l1 l2 n') "Hσ1 /="; destruct σ1; simpl;
      iDestruct "Hσ1" as "[Hr Hm]";
      iDestruct (@gen_heap_valid with "Hr HPC") as %?;
      iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?;
      iDestruct (@gen_heap_valid with "Hr Hr2") as %?;
      option_locate_mr m r).
     iApply fupd_frame_l.
     iSplit.
     - rewrite /reducible.
       iExists [], Failed, (r, m), [].
       iPureIntro.
       constructor.
       destruct Hinstr as [Hinstr | [Hinstr | Hinstr]].
       + apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (cap_lang.Add dst x (inr r2))
                              (Failed,_));
         eauto; simpl; try congruence.
         rewrite Hr2. destruct x; auto. destruct (r !r! r0); auto.
       + apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Sub dst x (inr r2))
                              (Failed,_));
         eauto; simpl; try congruence.
         rewrite Hr2. destruct x; auto. destruct (r !r! r0); auto.
       + apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Lt dst x (inr r2))
                              (Failed,_));
         eauto; simpl; try congruence.
         rewrite Hr2. destruct x; auto. destruct (r !r! r0); auto.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep). destruct Hinstr as [Hinstr | [Hinstr | Hinstr]];
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       + rewrite Hr2. assert (X: match x with
                  | inl _ => (Failed, (r, m))
                  | inr r1 => match r !r! r1 with
                              | inl _ | _ => (Failed, (r, m))
                              end
                                 end = (Failed, (r, m))).
         { destruct x; auto. destruct (r !r! r0); auto. }
         rewrite X.
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.         
         iApply wp_value; by iApply "Hφ".
       + rewrite Hr2. assert (X: match x with
                  | inl _ => (Failed, (r, m))
                  | inr r1 => match r !r! r1 with
                              | inl _ | _ => (Failed, (r, m))
                              end
                                 end = (Failed, (r, m))).
         { destruct x; auto. destruct (r !r! r0); auto. }
         rewrite X.
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.         
         iApply wp_value; by iApply "Hφ".
       + rewrite Hr2. assert (X: match x with
                  | inl _ => (Failed, (r, m))
                  | inr r1 => match r !r! r1 with
                              | inl _ | _ => (Failed, (r, m))
                              end
                                 end = (Failed, (r, m))).
         { destruct x; auto. destruct (r !r! r0); auto. }
         rewrite X.
         iFrame. iModIntro. iNext.
         iApply fupd_frame_l. iFrame.         
         iApply wp_value; by iApply "Hφ".
   Qed.


 (* --------------------------------------------------------------------------------- *)
 (* -------------------------------- SUCCESS RULES ---------------------------------- *)
   
   Lemma wp_load_success E r1 r2 pc_p pc_g pc_b pc_e pc_a w w' w'' p g b e a pc_a' φ :
    cap_lang.decode w = Load r1 r2 →
    isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
    readAllowed p = true ∧ withinBounds ((p, g), b, e, a) = true →
    (pc_a + 1)%a = Some pc_a' →
    r1 ≠ PC →
    
   
    PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
    ∗ pc_a ↦ₐ w
    ∗ r1 ↦ᵣ w''  
    ∗ r2 ↦ᵣ inr ((p,g),b,e,a)
    ∗ a ↦ₐ w'
    ∗  ▷ ( PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a') ∗ r1 ↦ᵣ w' 
          ∗ pc_a ↦ₐ w -∗ WP Executable @ E {{ φ }})
    ⊢
    WP Executable @ E {{ φ }}.
   Proof.
     intros Hinstr Hvpc [Hra Hwb] Hpca' Hne1. 
     iIntros "(Hpc & Hi & Hr1 & Hr2 & Hr2a & Hφ)".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hm Hr2a") as %?.
     iDestruct (@gen_heap_valid with "Hr Hpc") as %?.
     iDestruct (@gen_heap_valid with "Hm Hi") as %?.
     iDestruct (@gen_heap_valid with "Hr Hr2") as %?.
     option_locate_mr m r. 
     assert (<[r1:=m !m! a]> r !r! PC = (inr (pc_p, pc_g, pc_b, pc_e, pc_a)))
       as Hpc_new1.
     { rewrite (locate_ne_reg _ _ _ (inr (pc_p, pc_g, pc_b, pc_e, pc_a))); eauto. }
     iApply fupd_frame_l. 
     iSplit.  
     - rewrite /reducible. 
       iExists [], Executable, (updatePC (update_reg (r,m) r1 (MemLocate m a))).2,[].
       rewrite /updatePC Hpc_new1 Ha /update_reg /=.
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a (Load r1 r2)
                              (Executable,_));
         eauto; simpl; try congruence. 
        rewrite /withinBounds in Hwb; rewrite Hr2 Hra Hwb /updatePC /= Hpc_new1.
        by rewrite Hpca' /update_reg /= Ha.
     - iMod (fupd_intro_mask' E ∅) as "H"; first solve_ndisj. 
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep Hpc_new1.
       rewrite Hr2 Hra Hwb /update_reg /updatePC /= Hpc_new1 /=.
       inv_head_step.
       rewrite Hr2 Hra Hwb /= /update_reg /updatePC /= Hpc_new1 /update_reg /= in Hstep. 
       iMod (@gen_heap_update with "Hr Hr1") as "[Hr Hr1]".
       iMod (@gen_heap_update with "Hr Hpc") as "[$ Hpc]".
       iSpecialize ("Hφ" with "[Hpc Hr1 Hi]"); iFrame.  
       iModIntro. iNext. iFrame.
   Qed.        

   
   Lemma wp_jmp_success pc_p pc_g pc_b pc_e pc_a w r g b e a φ :
     cap_lang.decode w = Jmp r →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     
     ▷ ( PC ↦ᵣ inr ((RX,g),b,e,a) -∗  WP Executable {{ φ }} )
       ∗ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
       ∗ pc_a ↦ₐ w
       ∗ r ↦ᵣ inr ((E,g),b,e,a)
       ⊢
       WP Executable {{ φ }}.
   Proof.
     intros Hinstr Hvpc.
     iIntros "(Hφ & HPC & Hpc_a & Hr)".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr0 Hm]".
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?.
     iDestruct (@gen_heap_valid with "Hr0 HPC") as %?.
     iDestruct (@gen_heap_valid with "Hr0 Hr") as %?.
     option_locate_mr m r0.
     iApply fupd_frame_l. 
     iSplit.
     - rewrite /reducible.
       iExists [],Executable,(<[PC:=inr (RX, g, b, e, a)]> r0, m),[].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r0,m) pc_p pc_g pc_b pc_e pc_a (Jmp r)
                              (Executable,_)); eauto; simpl; try congruence.
         by rewrite Hr /updatePcPerm /update_reg /=.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro. 
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r0 HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hr /updatePcPerm /=.
       inv_head_step.
       rewrite Hr /updatePcPerm /update_reg /= in Hstep.
       iMod (@gen_heap_update with "Hr0 HPC") as "[Hr0 HPC]".
       iSpecialize ("Hφ" with "[HPC]"); iFrame.  
       iModIntro. iNext. iFrame. 
   Qed.
   

   Lemma wp_subseg_success pc_p pc_g pc_b pc_e pc_a pc_a' w dst r1 r2 p g b e a n1 n2 a1 a2 φ :
     cap_lang.decode w = Subseg dst (inr r1) (inr r2) →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     (pc_a + 1)%a = Some pc_a' →
     z_to_addr n1 = Some a1 ∧ z_to_addr n2 = Some a2 →
     p ≠ E →
     dst ≠ PC →
     isWithin a1 a2 b e = true →
     
     ▷ ( PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a')
            ∗ dst ↦ᵣ inr (p, g, a1, if (a2 =? -42)%a then None else Some a2, a)
            -∗  WP Executable {{ φ }} )
       ∗ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
       ∗ pc_a ↦ₐ w
       ∗ dst ↦ᵣ inr ((p,g),b,e,a)
       ∗ r1 ↦ᵣ inl n1
       ∗ r2 ↦ᵣ inl n2      
       ⊢
       WP Executable {{ φ }}.
   Proof.
     intros Hinstr Hvpc Hpca' [Hn1 Hn2] Hpne Hdstne Hwb.
     iIntros "(Hφ & HPC & Hpc_a & Hdst & Hr1 & Hr2)".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?.
     iDestruct (@gen_heap_valid with "Hr HPC") as %?.
     iDestruct (@gen_heap_valid with "Hr Hdst") as %?.
     iDestruct (@gen_heap_valid with "Hr Hr1") as %?.
     iDestruct (@gen_heap_valid with "Hr Hr2") as %?.
     option_locate_mr m r.
     assert (<[dst:=inr (p, g, a1, if (a2 =? -42)%a then None
                                   else Some a2, a)]>
             r !r! PC = (inr (pc_p, pc_g, pc_b, pc_e, pc_a)))
       as Hpc_new1.
     { rewrite (locate_ne_reg _ _ _ (inr (pc_p, pc_g, pc_b, pc_e, pc_a))); eauto. }
     iApply fupd_frame_l. 
     iSplit.
     - rewrite /reducible.
       iExists [],Executable,
       (updatePC (update_reg (r,m) dst (inr ((p, g), a1,
            if (a2 =? (-42))%a then None else Some a2, a)))).2,[].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a
                              (Subseg dst (inr r1) (inr r2))
                              (Executable,_)); eauto; simpl; try congruence.
       rewrite Hdst. destruct p; (try congruence;
        by rewrite Hr1 Hr2 Hn1 Hn2 Hwb /updatePC /update_reg /= Hpc_new1 Hpca').
     - destruct p; try congruence;
        (iMod (fupd_intro_mask' ⊤) as "H"; eauto;
         iModIntro;
         iIntros (e1 σ2 efs Hstep);
         inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep Hpc_new1;
         rewrite Hdst Hr1 Hr2 Hn1 Hn2 Hwb /updatePC /update_reg Hpc_new1 Hpca' /=;
         inv_head_step;
         rewrite Hdst Hr1 Hr2 Hn1 Hn2 Hwb /updatePC /update_reg Hpc_new1 Hpca' /= in Hstep;
         iMod (@gen_heap_update with "Hr Hdst") as "[Hr Hdst]";
         iMod (@gen_heap_update with "Hr HPC") as "[$ HPC]";
         iSpecialize ("Hφ" with "[HPC Hdst]"); iFrame;
         iModIntro; iNext; iFrame).
   Qed.

   Lemma wp_subseg_success_pc pc_p pc_g pc_b pc_e pc_a pc_a' w r1 r2 n1 n2 a1 a2 φ :
     cap_lang.decode w = Subseg PC (inr r1) (inr r2) →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     (pc_a + 1)%a = Some pc_a' →
     z_to_addr n1 = Some a1 ∧ z_to_addr n2 = Some a2 →
     pc_p ≠ E →
     isWithin a1 a2 pc_b pc_e = true →
     
     ▷ ( PC ↦ᵣ inr ((pc_p,pc_g),a1,if (a2 =? -42)%a then None else Some a2,pc_a')
            -∗  WP Executable {{ φ }} )
       ∗ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
       ∗ pc_a ↦ₐ w
       ∗ r1 ↦ᵣ inl n1
       ∗ r2 ↦ᵣ inl n2      
       ⊢
       WP Executable {{ φ }}.
   Proof.
     intros Hinstr Hvpc Hpca' [Hn1 Hn2] Hpne Hwb.
     iIntros "(Hφ & HPC & Hpc_a & Hr1 & Hr2)".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?.
     iDestruct (@gen_heap_valid with "Hr Hr1") as %?.
     iDestruct (@gen_heap_valid with "Hr HPC") as %?.
     iDestruct (@gen_heap_valid with "Hr Hr2") as %?.
     option_locate_mr m r.
     assert (<[PC:=inr (pc_p, pc_g, a1, if (a2 =? -42)%a then None
                                   else Some a2, pc_a)]>
             r !r! PC = inr (pc_p, pc_g, a1, if (a2 =? -42)%a then None
                                   else Some a2, pc_a))
       as Hpc_new1; first by rewrite /RegLocate lookup_insert. 
     iApply fupd_frame_l. 
     iSplit.
     - rewrite /reducible.
       iExists [],Executable,
       (updatePC (update_reg (r,m) PC (inr ((pc_p, pc_g), a1,
            if (a2 =? (-42))%a then None else Some a2, pc_a)))).2,[].
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a
                              (Subseg PC (inr r1) (inr r2))
                              (Executable,_)); eauto; simpl; try congruence.
       rewrite HPC. destruct pc_p; (try congruence;
       by rewrite Hr1 Hr2 Hn1 Hn2 Hwb /updatePC /update_reg /= Hpc_new1 Hpca').
     - destruct pc_p; try congruence;
        (iMod (fupd_intro_mask' ⊤) as "H"; eauto;
         iModIntro;
         iIntros (e1 σ2 efs Hstep);
         inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep Hpc_new1;
         rewrite HPC Hr1 Hr2 Hn1 Hn2 Hwb /updatePC /update_reg Hpc_new1 Hpca' /= insert_insert;
         inv_head_step;
         rewrite HPC Hr1 Hr2 Hn1 Hn2 Hwb /updatePC /update_reg Hpc_new1 Hpca' /= insert_insert
           in Hstep;
         iMod (@gen_heap_update with "Hr HPC") as "[$ HPC]";
         iSpecialize ("Hφ" with "[HPC]"); iFrame;
         iModIntro; iNext; iFrame).
   Qed.

   Lemma wp_IsPtr_success_S pc_p pc_g pc_b pc_e pc_a pc_a' w dst r ptr w' φ :
     cap_lang.decode w = IsPtr dst r →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     (pc_a + 1)%a = Some pc_a' →
     dst ≠ PC →  

      ▷ ( PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a') ∗ dst ↦ᵣ inl 1%Z
            -∗  WP Executable {{ φ }} )
       ∗ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
       ∗ pc_a ↦ₐ w
       ∗ r ↦ᵣ inr ptr
       ∗ dst ↦ᵣ w'
       ⊢
       WP Executable {{ φ }}.
   Proof.
     intros Hinstr Hvpc Hpca' Hne.
     iIntros "(Hφ & HPC & Hpc_a & Hr & Hdst)".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr0 Hm]".
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?.
     iDestruct (@gen_heap_valid with "Hr0 Hr") as %?.
     iDestruct (@gen_heap_valid with "Hr0 HPC") as %?.
     iDestruct (@gen_heap_valid with "Hr0 Hdst") as %?.
     option_locate_mr m r0.
     assert (<[dst:=inl 1%Z]> r0 !r! PC = (inr (pc_p, pc_g, pc_b, pc_e, pc_a))) as Hpc_new1.
     { rewrite (locate_ne_reg _ _ _ (inr (pc_p, pc_g, pc_b, pc_e, pc_a))); eauto. }
     iApply fupd_frame_l. 
     iSplit.
     - rewrite /reducible.
       iExists [], Executable,(<[PC:=inr (pc_p, pc_g, pc_b, pc_e, pc_a')]> (<[dst:=inl 1%Z]> r0), m), [].
       iPureIntro.
       constructor. 
       apply (step_exec_instr (r0,m) pc_p pc_g pc_b pc_e pc_a
                              (IsPtr dst r)
                              (Executable,_)); eauto; simpl; try congruence.
         by rewrite Hr /update_reg /updatePC /= Hpc_new1 Hpca' /update_reg /updatePC /=.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro.
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r0 HPC Hpc_a Hinstr Hstep Hpc_new1.
       rewrite Hr /updatePC /update_reg /= Hpc_new1 Hpca' /=.
       iMod (@gen_heap_update with "Hr0 Hdst") as "[Hr0 Hdst]".
       iMod (@gen_heap_update with "Hr0 HPC") as "[$ HPC]".
       iSpecialize ("Hφ" with "[HPC Hdst]"); iFrame.
       iModIntro. iNext. iFrame.
   Qed.

   Lemma wp_IsPtr_success_F pc_p pc_g pc_b pc_e pc_a pc_a' w dst r z w' φ :
     cap_lang.decode w = IsPtr dst r →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     (pc_a + 1)%a = Some pc_a' →
     dst ≠ PC →  

      ▷ ( PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a') ∗ dst ↦ᵣ inl 0%Z
            -∗  WP Executable {{ φ }} )
       ∗ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
       ∗ pc_a ↦ₐ w
       ∗ r ↦ᵣ inl z
       ∗ dst ↦ᵣ w'
       ⊢
       WP Executable {{ φ }}.
   Proof.
     intros Hinstr Hvpc Hpca' Hne.
     iIntros "(Hφ & HPC & Hpc_a & Hr & Hdst)".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr0 Hm]".
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?.
     iDestruct (@gen_heap_valid with "Hr0 Hr") as %?.
     iDestruct (@gen_heap_valid with "Hr0 HPC") as %?.
     iDestruct (@gen_heap_valid with "Hr0 Hdst") as %?.
     option_locate_mr m r0.
     assert (<[dst:=inl 0%Z]> r0 !r! PC = (inr (pc_p, pc_g, pc_b, pc_e, pc_a))) as Hpc_new1.
     { rewrite (locate_ne_reg _ _ _ (inr (pc_p, pc_g, pc_b, pc_e, pc_a))); eauto. }
     iApply fupd_frame_l. 
     iSplit.
     - rewrite /reducible.
       iExists [], Executable,(<[PC:=inr (pc_p, pc_g, pc_b, pc_e, pc_a')]> (<[dst:=inl 0%Z]> r0), m), [].
       iPureIntro.
       constructor. 
       apply (step_exec_instr (r0,m) pc_p pc_g pc_b pc_e pc_a
                              (IsPtr dst r)
                              (Executable,_)); eauto; simpl; try congruence.
       by rewrite Hr /update_reg /updatePC /= Hpc_new1 Hpca' /update_reg /updatePC /=.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro.
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r0 HPC Hpc_a Hinstr Hstep Hpc_new1.
       rewrite Hr /updatePC /update_reg /= Hpc_new1 Hpca' /=.
       iMod (@gen_heap_update with "Hr0 Hdst") as "[Hr0 Hdst]".
       iMod (@gen_heap_update with "Hr0 HPC") as "[$ HPC]".
       iSpecialize ("Hφ" with "[HPC Hdst]"); iFrame.
       iModIntro. iNext. iFrame.
   Qed.


   Lemma wp_store_success_local pc_p pc_g pc_b pc_e pc_a pc_a' w dst src w'
         p g b e a p' g' b' e' a' φ :
     cap_lang.decode w = Store dst (inr src) →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     (pc_a + 1)%a = Some pc_a' →
     writeAllowed p = true ∧ withinBounds ((p, g), b, e, a) = true →
     isLocal g' = true ∧ (p = RWLX ∨ p = RWL) → 
     dst ≠ PC →

     ▷ ( PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a') ∗ a ↦ₐ inr ((p',g'),b',e',a') 
            -∗  WP Executable {{ φ }} )
       ∗ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a)
       ∗ pc_a ↦ₐ w
       ∗ src ↦ᵣ inr ((p',g'),b',e',a')
       ∗ dst ↦ᵣ inr ((p,g),b,e,a)  
       ∗ a ↦ₐ w'
       ⊢
       WP Executable {{ φ }}.
   Proof.
     intros Hinstr Hvpc Hpca' [Hwa Hwb] [Hlocal Hp] Hne; simpl in *. 
     iIntros "(Hφ & HPC & Hpc_a & Hsrc & Hdst & Ha)".
     iApply wp_lift_step_fupd; eauto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hr HPC") as %?.
     iDestruct (@gen_heap_valid with "Hm Hpc_a") as %?.
     iDestruct (@gen_heap_valid with "Hr Hsrc") as %?.
     iDestruct (@gen_heap_valid with "Hr Hdst") as %?.
     iDestruct (@gen_heap_valid with "Hm Ha") as %?.
     option_locate_mr m r.
     iApply fupd_frame_l. 
     iSplit.
     - rewrite /reducible.
       iExists [],Executable,(updatePC (update_mem (r,m) a (RegLocate r src))).2, [].
       iPureIntro.
       constructor. 
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a
                              (Store dst (inr src))
                              (Executable,_)); eauto; simpl; try congruence.
       rewrite Hdst Hwa Hwb /= Hsrc Hlocal.
       destruct Hp as [Hp | Hp]; try contradiction;
         by rewrite Hp /updatePC /update_mem /= HPC Hpca'.
     - iMod (fupd_intro_mask' ⊤) as "H"; eauto.
       iModIntro.
       iIntros (e1 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       rewrite Hdst Hwa Hwb /= Hsrc Hlocal.
       destruct Hp as [Hp | Hp]; try contradiction;
       ( rewrite Hp /updatePC /update_mem /= HPC /update_reg /= Hpca';
         iMod (@gen_heap_update with "Hm Ha") as "[$ Ha]";
         iMod (@gen_heap_update with "Hr HPC") as "[$ HPC]";
         iSpecialize ("Hφ" with "[HPC Ha]"); iFrame; eauto ). 
   Qed. 
       
       
 (* --------------------------------------------------------------------------------- *)
 (* ----------------------------------- ATOMIC RULES -------------------------------- *)

   Lemma wp_halt pc_p pc_g pc_b pc_e pc_a w :
     cap_lang.decode w = Halt →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     
     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a) ∗ pc_a ↦ₐ w }}}
       Executable 
     {{{ RET HaltedV; PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a) ∗ pc_a ↦ₐ w }}}.
   Proof.
     intros Hinstr Hvpc. 
     iIntros (φ) "[Hpc Hpca] Hφ".
     iApply wp_lift_atomic_step_fupd; auto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hr Hpc") as %?.
     iDestruct (@gen_heap_valid with "Hm Hpca") as %?.
     option_locate_mr m r. 
     iModIntro.
     iSplitR.
     - rewrite /reducible. 
       iExists [],Halted,(r,m),[].       
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a Halt
                              (Halted,_));
         eauto; simpl; try congruence.
     - iIntros (e2 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       iFrame.
       iModIntro. iNext. iModIntro. iSplitL; eauto. 
       iApply "Hφ".
       iFrame.
   Qed.

   Lemma wp_fail pc_p pc_g pc_b pc_e pc_a w :
     cap_lang.decode w = Fail →
     isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,pc_a)) →
     
     {{{ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a) ∗ pc_a ↦ₐ w }}}
       Executable 
     {{{ RET FailedV; PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,pc_a) ∗ pc_a ↦ₐ w }}}.
   Proof.
     intros Hinstr Hvpc. 
     iIntros (φ) "[Hpc Hpca] Hφ".
     iApply wp_lift_atomic_step_fupd; auto.
     iIntros (σ1 l1 l2 n) "Hσ1 /=". destruct σ1; simpl.
     iDestruct "Hσ1" as "[Hr Hm]".
     iDestruct (@gen_heap_valid with "Hr Hpc") as %?.
     iDestruct (@gen_heap_valid with "Hm Hpca") as %?.
     option_locate_mr m r. 
     iModIntro.
     iSplitR.
     - rewrite /reducible. 
       iExists [],Failed,(r,m),[].       
       iPureIntro.
       constructor.
       apply (step_exec_instr (r,m) pc_p pc_g pc_b pc_e pc_a Fail
                              (Failed,_));
         eauto; simpl; try congruence.
     - iIntros (e2 σ2 efs Hstep).
       inv_head_step_advanced m r HPC Hpc_a Hinstr Hstep HPC.
       iFrame.
       iModIntro. iNext. iModIntro. iSplitL; eauto. 
       iApply "Hφ".
       iFrame.
   Qed.

End cap_lang_rules. 