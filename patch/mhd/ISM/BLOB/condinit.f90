!================================================================
!================================================================
!================================================================
!================================================================
subroutine condinit(x,u,dx,nn)
  use amr_parameters
!  use hydro_parameters
  use hydro_commons
  implicit none
  integer ::nn                            ! Number of cells
  real(dp)::dx                            ! Cell size
  real(dp),dimension(1:nvector,1:nvar+3)::u ! Conservative variables
  real(dp),dimension(1:nvector,1:ndim)::x ! Cell center position.
  !================================================================
  ! This routine generates initial conditions for RAMSES.
  ! Positions are in user units:
  ! x(i,1:3) are in [0,boxlen]**ndim.
  ! U is the conservative variable vector. Conventions are here:
  ! U(i,1): d, U(i,2:4): d.u,d.v,d.w, U(i,5): E, U(i,6:8): Bleft, 
  ! U(i,nvar+1:nvar+3): Bright
  ! Q is the primitive variable vector. Conventions are here:
  ! Q(i,1): d, Q(i,2:4):u,v,w, Q(i,5): P, Q(i,6:8): Bleft, 
  ! Q(i,nvar+1:nvar+3): Bright
  ! If nvar > 8, remaining variables (9:nvar) are treated as passive
  ! scalars in the hydro solver.
  ! U(:,:) and Q(:,:) are in user units.
  !================================================================
  integer::ivar,i
  real(dp),dimension(1:nvector,1:nvar+3),save::q   ! Primitive variables
  real(dp)::pi,xx,yy
  real(dp)::scale_l,scale_t,scale_d,scale_v,scale_nH,scale_T2,mag_norm,Cwnm,rad


  ! Call built-in initial condition generator
!  call region_condinit(x,q,dx,nn)

  ! Add here, if you wish, some user-defined initial conditions
  ! ........
  pi=ACOS(-1.0d0)


  mass_sph = 10. * (boxlen*(0.5**levelmin))**3

  call units(scale_l,scale_t,scale_d,scale_v,scale_nH,scale_T2)
!  write(*,*) 'Echelle de temperature',scale_T2
!  write(*,*) 'temperature du code',8000./scale_T2
!  write(*,*) 'dens0 ',dens0

!   mag_norm = sqrt(dens0*8000./scale_T2*2.*1.5)

   mag_norm = sqrt(1.*8000./scale_T2*2.*1.5)

   Cwnm = sqrt(8000./scale_T2)

   temper = (8000. / scale_T2 ) / dens0

     if (isothermal) temper = temper_iso / scale_T2

!     write(*,*) 'isothermal, temper_iso', isothermal, temper_iso
 

  do i=1,nn


     !Bx component
     q(i,6     ) = bx_bound * mag_norm
     q(i,nvar+1) = bx_bound * mag_norm

     !By component
     q(i,7     ) = by_bound * mag_norm
     q(i,nvar+2) = by_bound * mag_norm

     !Bz component
     q(i,8     ) = bz_bound * mag_norm
     q(i,nvar+3) = bz_bound * mag_norm

     !en cgs
        !densite



       x(i,1) = x(i,1) - 0.5*boxlen
       x(i,2) = x(i,2) - 0.5*boxlen
       x(i,3) = x(i,3) - 0.5*boxlen

       rad = sqrt(x(i,1)**2+x(i,2)**2+x(i,3)**2)


     if(rad .lt. boxlen / 20.) then

     q(i,1) = dens0 !* ( 1. + 0.1 * cos(xx/25*pi) * cos(yy/25*pi+1.245) + 0.1 * cos(xx/10*pi+ 2.56) * cos(yy/10*pi+0.356))
        !pression
     q(i,5) = q(i,1) * temper
!     q(i,5) = q(i,1) * (50. / scale_T2)

     q(i,2)=0. 
     q(i,3)=0. 
     q(i,4)=0.

     else

     q(i,1) = dens0 /30. !* ( 1. + 0.1 * cos(xx/25*pi) * cos(yy/25*pi+1.245) + 0.1 * cos(xx/10*pi+ 2.56) * cos(yy/10*pi+0.356))
        !pression
     q(i,5) = q(i,1) * temper * 30.
!     q(i,5) = q(i,1) * (50. / scale_T2)

     q(i,2)=3.*Cwnm
     q(i,3)=0.*Cwnm
     q(i,4)=0.*Cwnm


     endif


!      write(*,*) q(i,6),q(i,7),q(i,8)
  end do


  ! Convert primitive to conservative variables
  ! density -> density
  u(1:nn,1)=q(1:nn,1)
  ! velocity -> momentum
  u(1:nn,2)=q(1:nn,1)*q(1:nn,2)
  u(1:nn,3)=q(1:nn,1)*q(1:nn,3)
  u(1:nn,4)=q(1:nn,1)*q(1:nn,4)
  ! kinetic energy
  u(1:nn,5)=0.0d0
  u(1:nn,5)=u(1:nn,5)+0.5*q(1:nn,1)*q(1:nn,2)**2
  u(1:nn,5)=u(1:nn,5)+0.5*q(1:nn,1)*q(1:nn,3)**2
  u(1:nn,5)=u(1:nn,5)+0.5*q(1:nn,1)*q(1:nn,4)**2
  !kinetic + magnetic energy
  u(1:nn,5)=u(1:nn,5)+0.125*(q(1:nn,6)+q(1:nn,nvar+1))**2
  u(1:nn,5)=u(1:nn,5)+0.125*(q(1:nn,7)+q(1:nn,nvar+2))**2
  u(1:nn,5)=u(1:nn,5)+0.125*(q(1:nn,8)+q(1:nn,nvar+3))**2
  ! pressure -> total fluid energy
  u(1:nn,5)=u(1:nn,5)+q(1:nn,5)/(gamma-1.0d0)
  ! magnetic field 
  u(1:nn,6:8)=q(1:nn,6:8)
  u(1:nn,nvar+1:nvar+3)=q(1:nn,nvar+1:nvar+3)
  ! passive scalars
  do ivar=9,nvar
     u(1:nn,ivar)=q(1:nn,1)*q(1:nn,ivar)
  end do


end subroutine condinit
!================================================================
!================================================================
!================================================================
!================================================================
subroutine velana(x,v,dx,t,ncell)
  use amr_parameters
  use hydro_parameters  
  implicit none
  integer ::ncell                         ! Size of input arrays
  real(dp)::dx                            ! Cell size
  real(dp)::t                             ! Current time
  real(dp),dimension(1:nvector,1:3)::v    ! Velocity field
  real(dp),dimension(1:nvector,1:ndim)::x ! Cell center position.
  !================================================================
  ! This routine computes the user defined velocity fields.
  ! x(i,1:ndim) are cell center position in [0,boxlen] (user units).
  ! v(i,1:3) is the imposed 3-velocity in user units.
  !================================================================
  integer::i
  real(dp)::xx,yy,zz,vx,vy,vz,rr,tt,omega,aa,twopi

  ! Add here, if you wish, some user-defined initial conditions
  aa=1.0
  twopi=2d0*ACOS(-1d0)
  do i=1,ncell

     xx=x(i,1)
     yy=x(i,2)
     zz=x(i,3)

     ! ABC
     vx=aa*(cos(twopi*yy)+sin(twopi*zz))
     vy=aa*(sin(twopi*xx)+cos(twopi*zz))
     vz=aa*(cos(twopi*xx)+sin(twopi*yy))

!!$     ! 1D advection test
!!$     vx=1.0_dp
!!$     vy=0.0_dp
!!$     vz=0.0_dp

!!$     ! Ponomarenko
!!$     xx=xx-boxlen/2.0
!!$     yy=yy-boxlen/2.0
!!$     rr=sqrt(xx**2+yy**2)
!!$     if(yy>0)then
!!$        tt=acos(xx/rr)
!!$     else
!!$        tt=-acos(xx/rr)+twopi
!!$     endif
!!$     if(rr<1.0)then
!!$        omega=0.609711
!!$        vz=0.792624
!!$     else
!!$        omega=0.0
!!$        vz=0.0
!!$     endif
!!$     vx=-sin(tt)*rr*omega
!!$     vy=+cos(tt)*rr*omega
     
     v(i,1)=vx
     v(i,2)=vy
     v(i,3)=vz

  end do


end subroutine velana
