subroutine read_hydro_params(nml_ok)
  use amr_commons
  use hydro_commons
  implicit none
#ifndef WITHOUTMPI
  include 'mpif.h'
#endif
  logical::nml_ok
  !--------------------------------------------------
  ! Local variables  
  !--------------------------------------------------
  integer::i,idim,nboundary_true=0
  integer ,dimension(1:MAXBOUND)::bound_type
  real(dp)::scale,ek_bound,em_bound
  character(len=80):: sn_list
  real(dp):: scale_l, scale_t, scale_d, scale_v, scale_nH, scale_T2


  !--------------------------------------------------
  ! Namelist definitions
  !--------------------------------------------------
  namelist/init_params/filetype,initfile,multiple,nregion,region_type &
       & ,x_center,y_center,z_center,aexp_ini &
       & ,length_x,length_y,length_z,exp_region &
       & ,d_region,u_region,v_region,w_region,p_region &
       & ,A_region,B_region,C_region
  namelist/hydro_params/gamma,courant_factor,smallr,smallc &
       & ,niter_riemann,slope_type &
       & ,pressure_fix,beta_fix,scheme,riemann,riemann2d,switch_solv
  namelist/refine_params/x_refine,y_refine,z_refine,r_refine &
       & ,a_refine,b_refine,exp_refine,jeans_refine,mass_cut_refine &
       & ,m_refine,mass_sph,err_grad_d,err_grad_p,err_grad_u &
       & ,err_grad_A,err_grad_B,err_grad_C,err_grad_B2 &
       & ,floor_d,floor_u,floor_p,ivar_refine,var_cut_refine &
       & ,floor_A,floor_B,floor_C,floor_B2 &
       & ,interpol_var,interpol_type
  namelist/boundary_params/nboundary,bound_type &
       & ,ibound_min,ibound_max,jbound_min,jbound_max &
       & ,kbound_min,kbound_max &
       & ,d_bound,u_bound,v_bound,w_bound,p_bound &
       & ,A_bound,B_bound,C_bound
  namelist/physics_params/cooling,haardt_madau,metal,isothermal,bondi &
       & ,m_star,t_star,n_star,T2_star,g_star,del_star,eps_star,jeans_ncells &
       & ,eta_sn,yield,rbubble,f_ek,ndebris,f_w,mass_gmc &
       & ,J21,a_spec,z_ave,z_reion,eta_mag,n_sink,bondi,delayed_cooling &
       & ,self_shielding,smbh,agn,rsink_max,msink_max &
       & ,bx_bound,by_bound,bz_bound,turb,dens0,V0,eta_mag,temper_iso, Height0 &
       & ,sn_list, sn_freq_mult, supernovae, dens_corr, eff_sn, feedback_sink ! supernova list file


  ! Read namelist file
  rewind(1)
  read(1,NML=init_params,END=101)
  goto 102
101 write(*,*)' You need to set up namelist &INIT_PARAMS in parameter file'
  call clean_stop
102 rewind(1)
  if(nlevelmax>levelmin)read(1,NML=refine_params)
  rewind(1)
  if(hydro)read(1,NML=hydro_params)
  rewind(1)
  read(1,NML=boundary_params,END=103)
  simple_boundary=.true.
  goto 104
103 simple_boundary=.false.
104 if(nboundary>MAXBOUND)then
    write(*,*) 'Error: nboundary>MAXBOUND'
    call clean_stop
  end if
  rewind(1)
  read(1,NML=physics_params,END=105)



  ! Read supernova list 
  if(supernovae) then
    if(sn_freq_mult .ne. 0) then
    ! Conversion factor from user units to cgs units
      call units(scale_l,scale_t,scale_d,scale_v,scale_nH,scale_T2)
      sn_freq = 50. * (3.1416*8000.**2) / boxlen**2 !standard freq one SN per 50 years in the MW
      sn_freq = sn_freq * (3600.*24.*365.) / scale_t !conversion in code units
      sn_freq = sn_freq * sn_freq_mult !adjust to some multiplication factor
      sn_e_ref = 1.d51 / (scale_d * scale_v**2 * scale_l**3)
      sn_mass_ref = 2.d34 / (scale_d * scale_l**3) !5 solar mass ejected
    else
      call read_sn_list(sn_list)
    endif
  endif


105 continue

  !--------------------------------------------------
  ! Make sure virtual boundaries are expanded to 
  ! account for staggered mesh representation
  !--------------------------------------------------
  nexpand_bound=2

  !--------------------------------------------------
  ! Check for star formation
  !--------------------------------------------------
  if(t_star>0)then
     star=.true.
     pic=.true.
  else if(eps_star>0)then
     t_star=0.1635449*(n_star/0.1)**(-0.5)/eps_star
     star=.true.
     pic=.true.
  endif

  !--------------------------------------------------
  ! Check for metal
  !--------------------------------------------------
  if(metal.and.nvar<(ndim+6))then
     if(myid==1)write(*,*)'Error: metals need nvar >= ndim+6'
     if(myid==1)write(*,*)'Modify hydro_parameters.f90 and recompile'
     nml_ok=.false.
  endif

  !-------------------------------------------------
  ! This section deals with hydro boundary conditions
  !-------------------------------------------------
  if(simple_boundary.and.nboundary==0)then
     simple_boundary=.false.
  endif

  if (simple_boundary)then

     ! Compute new coarse grid boundaries
     do i=1,nboundary
        if(ibound_min(i)*ibound_max(i)==1.and.ndim>0.and.bound_type(i)>0)then
           nx=nx+1
           if(ibound_min(i)==-1)then
              icoarse_min=icoarse_min+1
              icoarse_max=icoarse_max+1
           end if
           nboundary_true=nboundary_true+1
        end if
     end do
     do i=1,nboundary
        if(jbound_min(i)*jbound_max(i)==1.and.ndim>1.and.bound_type(i)>0)then
           ny=ny+1
           if(jbound_min(i)==-1)then
              jcoarse_min=jcoarse_min+1
              jcoarse_max=jcoarse_max+1
           end if
           nboundary_true=nboundary_true+1
        end if
     end do
     do i=1,nboundary
        if(kbound_min(i)*kbound_max(i)==1.and.ndim>2.and.bound_type(i)>0)then
           nz=nz+1
           if(kbound_min(i)==-1)then
              kcoarse_min=kcoarse_min+1
              kcoarse_max=kcoarse_max+1
           end if
           nboundary_true=nboundary_true+1
        end if
     end do

     ! Compute boundary geometry
     do i=1,nboundary
        if(ibound_min(i)*ibound_max(i)==1.and.ndim>0.and.bound_type(i)>0)then
           if(ibound_min(i)==-1)then
              ibound_min(i)=icoarse_min+ibound_min(i)
              ibound_max(i)=icoarse_min+ibound_max(i)
              if(bound_type(i)==1)boundary_type(i)=1
              if(bound_type(i)==2)boundary_type(i)=11
              if(bound_type(i)==3)boundary_type(i)=21
           else
              ibound_min(i)=icoarse_max+ibound_min(i)
              ibound_max(i)=icoarse_max+ibound_max(i)
              if(bound_type(i)==1)boundary_type(i)=2
              if(bound_type(i)==2)boundary_type(i)=12
              if(bound_type(i)==3)boundary_type(i)=22
           end if
           if(ndim>1)jbound_min(i)=jcoarse_min+jbound_min(i)
           if(ndim>1)jbound_max(i)=jcoarse_max+jbound_max(i)
           if(ndim>2)kbound_min(i)=kcoarse_min+kbound_min(i)
           if(ndim>2)kbound_max(i)=kcoarse_max+kbound_max(i)
        else if(jbound_min(i)*jbound_max(i)==1.and.ndim>1.and.bound_type(i)>0)then
           ibound_min(i)=icoarse_min+ibound_min(i)
           ibound_max(i)=icoarse_max+ibound_max(i)
           if(jbound_min(i)==-1)then
              jbound_min(i)=jcoarse_min+jbound_min(i)
              jbound_max(i)=jcoarse_min+jbound_max(i)
              if(bound_type(i)==1)boundary_type(i)=3
              if(bound_type(i)==2)boundary_type(i)=13
              if(bound_type(i)==3)boundary_type(i)=23
           else
              jbound_min(i)=jcoarse_max+jbound_min(i)
              jbound_max(i)=jcoarse_max+jbound_max(i)
              if(bound_type(i)==1)boundary_type(i)=4
              if(bound_type(i)==2)boundary_type(i)=14
              if(bound_type(i)==3)boundary_type(i)=24
           end if
           if(ndim>2)kbound_min(i)=kcoarse_min+kbound_min(i)
           if(ndim>2)kbound_max(i)=kcoarse_max+kbound_max(i)
        else if(kbound_min(i)*kbound_max(i)==1.and.ndim>2.and.bound_type(i)>0)then
           ibound_min(i)=icoarse_min+ibound_min(i)
           ibound_max(i)=icoarse_max+ibound_max(i)
           jbound_min(i)=jcoarse_min+jbound_min(i)
           jbound_max(i)=jcoarse_max+jbound_max(i)
           if(kbound_min(i)==-1)then
              kbound_min(i)=kcoarse_min+kbound_min(i)
              kbound_max(i)=kcoarse_min+kbound_max(i)
              if(bound_type(i)==1)boundary_type(i)=5
              if(bound_type(i)==2)boundary_type(i)=15
              if(bound_type(i)==3)boundary_type(i)=25
           else
              kbound_min(i)=kcoarse_max+kbound_min(i)
              kbound_max(i)=kcoarse_max+kbound_max(i)
              if(bound_type(i)==1)boundary_type(i)=6
              if(bound_type(i)==2)boundary_type(i)=16
              if(bound_type(i)==3)boundary_type(i)=26
           end if
        end if
     end do
     do i=1,nboundary
        ! Check for errors
        if( (ibound_min(i)<0.or.ibound_max(i)>(nx-1)) .and. (ndim>0) .and.bound_type(i)>0 )then
           if(myid==1)write(*,*)'Error in the namelist'
           if(myid==1)write(*,*)'Check boundary conditions along X direction',i
           nml_ok=.false.
        end if
        if( (jbound_min(i)<0.or.jbound_max(i)>(ny-1)) .and. (ndim>1) .and.bound_type(i)>0)then
           if(myid==1)write(*,*)'Error in the namelist'
           if(myid==1)write(*,*)'Check boundary conditions along Y direction',i
           nml_ok=.false.
        end if
        if( (kbound_min(i)<0.or.kbound_max(i)>(nz-1)) .and. (ndim>2) .and.bound_type(i)>0)then
           if(myid==1)write(*,*)'Error in the namelist'
           if(myid==1)write(*,*)'Check boundary conditions along Z direction',i
           nml_ok=.false.
        end if
     end do
  end if
  nboundary=nboundary_true
  if(simple_boundary.and.nboundary==0)then
     simple_boundary=.false.
  endif

  !--------------------------------------------------
  ! Compute boundary conservative variables
  !--------------------------------------------------
  do i=1,nboundary
     boundary_var(i,1)=MAX(d_bound(i),smallr)
     boundary_var(i,2)=d_bound(i)*u_bound(i)
     boundary_var(i,3)=d_bound(i)*v_bound(i)
     boundary_var(i,4)=d_bound(i)*w_bound(i)
     boundary_var(i,6)=A_bound(i)
     boundary_var(i,7)=B_bound(i)
     boundary_var(i,8)=C_bound(i)
     boundary_var(i,nvar+1)=A_bound(i)
     boundary_var(i,nvar+2)=B_bound(i)
     boundary_var(i,nvar+3)=C_bound(i)
     ek_bound=0.5d0*d_bound(i)*(u_bound(i)**2+v_bound(i)**2+w_bound(i)**2)
     em_bound=0.5d0*(A_bound(i)**2+B_bound(i)**2+C_bound(i)**2)
     boundary_var(i,5)=ek_bound+em_bound+P_bound(i)/(gamma-1.0d0)
  end do

  !-----------------------------------
  ! Rearrange level dependent arrays
  !-----------------------------------
  do i=nlevelmax,levelmin,-1
     jeans_refine(i)=jeans_refine(i-levelmin+1)
  end do
  do i=1,levelmin-1
     jeans_refine(i)=-1.0
  end do

  !-----------------------------------
  ! Sort out passive variable indices
  !-----------------------------------
  imetal=9
  idelay=imetal
  if(metal)idelay=imetal+1
  ixion=idelay
  if(delayed_cooling)ixion=idelay+1
  ichem=ixion
  if(aton)ichem=ixion+1

end subroutine read_hydro_params

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine read_sn_list(sn_list)
  use amr_parameters
  use hydro_parameters
  use pm_parameters
  implicit none

  character(len=80):: sn_list
  integer:: i, ierr
  real(dp):: sn_length_scale, sn_mass_scale, sn_energy_scale, sn_time_scale
  real(dp):: sn_r, sn_m, sn_e, sn_t, sn_rp
  real(dp), dimension(3):: sn_c
  real(dp):: scale_l, scale_t, scale_d, scale_v, scale_nH, scale_T2

  call units(scale_l, scale_t, scale_d, scale_v, scale_nH, scale_T2)

  open(10, file=sn_list, form='formatted')
  read(10, *) sn_count, sn_length_scale, sn_mass_scale, sn_energy_scale, sn_time_scale, sn_npart

  if(sn_count > MAXSN) then
    write(*,*) "Too many supernovae, increase MAXSN to use them"
    call clean_stop
  endif
  if(sn_npart * sn_count > npartmax) then
    write(*,*) "Too many particles needed, increase npartmax to use them"
    call clean_stop
  endif


  if(sn_count == 0) then
    sn_all = .true.
  else
    do i = 1, sn_count
      read(10, *) sn_r, sn_m, sn_e, sn_t, sn_c(1), sn_c(2), sn_c(3), sn_rp
      sn_radius(i) = sn_r * sn_length_scale / scale_l
      sn_mass(i) = sn_m * sn_mass_scale / (scale_d * scale_l**3)
      sn_energy(i) = sn_e * sn_energy_scale / (scale_d * scale_v**2 * scale_l**3)
      sn_time(i) = sn_t * sn_time_scale / scale_t
      sn_center(i, :) = sn_c(:) * boxlen
      sn_part_radius(i) = sn_rp * sn_length_scale / scale_l
    end do
  end if
  close(10)
end subroutine read_sn_list
