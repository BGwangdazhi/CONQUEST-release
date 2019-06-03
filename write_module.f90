! Output for pseudopotentials and PAOs
module write

  implicit none

contains

  subroutine write_header(i_species)

    use datatypes
    use species_module, ONLY: n_species
    use input_module, ONLY: io_assign, io_close
    use pseudo_tm_info, ONLY: alloc_pseudo_info, pseudo, rad_alloc
    use pseudo_atom_info, ONLY: paos, val
    use periodic_table, ONLY: atomic_mass, pte
    use radial_xc, ONLY: flag_functional_type, functional_lda_pz81, functional_gga_pbe96, functional_description
    
    implicit none

    integer :: i_species
    
    integer :: lun, i, ell, en, i_shell
    character(len=80) :: filename
    character(len=2) :: string_xc
    
    call io_assign(lun)
    filename = trim(pte(pseudo(i_species)%z))//"CQ.ion"
    open(unit=lun, file=filename)
    ! Tag preamble
    write(lun,fmt='("<preamble>")')
    write(lun,fmt='("<Conquest_pseudopotential_info>")')
    write(lun,fmt='("")') ! Type - Hamann ONCV or Siesta TM
    write(lun,fmt='("")') ! Some PS identifier?
    write(lun,fmt='("")') ! Core radii
    write(lun,fmt='("")') ! Date of generation, version of PAO code
    write(lun,fmt='("")') ! XC functional
    write(lun,fmt='("</Conquest_pseudopotential_info>")')
    write(lun,fmt='("<Conquest_basis_specs>")')
    ! Give XC functional and seet functional label for later
    select case(flag_functional_type)
    case (functional_lda_pz81)
       string_xc = 'ca'
    case (functional_gga_pbe96)
       string_xc = 'pb'
    case default
       string_xc = 'xx'
    end select
    write(lun,fmt='((a)," basis set with ",(a)," functional")') trim(pte(pseudo(i_species)%z)), trim(functional_description)
    ! Loop over l
    !write(lun,fmt='("  n  l zetas  other")')
    paos%total_paos = 0
    do i_shell=1,paos%n_shells
       ell = paos%l(i_shell)
       en = paos%n(i_shell)
       paos%total_paos = paos%total_paos + paos%nzeta(i_shell)
       if(paos%flag_perturb_polarise.AND.i_shell==paos%n_shells) then
          if(en<3) en = en+1 ! OK - should an O polarised shell be 3d ?!
          write(lun,fmt='("n =",i2,", l =",i2,",",i2," zetas, perturbative polarisation shell")') &
               en, ell,paos%nzeta(i_shell)
       else if(i_shell<=val%n_occ) then 
          if(val%semicore(i_shell)>0) then
             write(lun,fmt='("n =",i2,", l =",i2,",",i2," zetas  Semi-core")') en, ell,paos%nzeta(i_shell)
          else
             write(lun,fmt='("n =",i2,", l =",i2,",",i2," zetas")') en, ell,paos%nzeta(i_shell)
          end if
       else
          write(lun,fmt='("n =",i2,", l =",i2,",",i2," zetas, polarisation shell")') en, ell,paos%nzeta(i_shell)
       end if
       ! Ugly hack: assume no more than five zetas to get formatting
       write(lun,fmt='(3x,"Radii: ",5f6.2)') (paos%cutoff(i,i_shell),i=1,paos%nzeta(i_shell))
    end do
    ! Give details of zetas, radii, semi-core, occupation
    write(lun,fmt='("</Conquest_basis_specs>")')
    write(lun,fmt='("<pseudopotential_header>")')
    ! Write symbol, functional, relativistic, PCC (pcec or nc)
    if(pseudo(i_species)%flag_pcc) then
       write(lun,fmt='(1x,a2," ",a2," nrl pcec")') pte(pseudo(i_species)%z), string_xc
    else
       write(lun,fmt='(1x,a2," ",a2," nrl nc  ")') pte(pseudo(i_species)%z), string_xc
    end if
    ! Only the last is used ! Get the format right
    write(lun,fmt='("</pseudopotential_header>")')
    write(lun,fmt='("</preamble>")')
    ! Symbol
    write(lun,fmt='(a2,20x,"# Element symbol")') pte(pseudo(i_species)%z)
    ! Label - how do we set this ? 
    write(lun,fmt='(a2,20x,"# Label")') pte(pseudo(i_species)%z)
    ! Atomic number
    write(lun,fmt='(i5,20x,"# Atomic number")') pseudo(i_species)%z
    ! Valence charge
    write(lun,fmt='(f18.10,20x,"# Valence charge")') pseudo(i_species)%zval
    ! Mass
    write(lun,fmt='(f18.10,20x,"# Mass")') atomic_mass(pseudo(i_species)%z)
    ! Self energy ?
    write(lun,fmt='(f18.10,20x,"# Self energy")') 0.0_double
    ! Lmax, no of nl orbitals BASIS
    paos%lmax = maxval(paos%l)
    write(lun,fmt='(2i4,20x,"# Lmax for basis, no of orbitals")') paos%lmax, paos%total_paos
    ! Lmax, no of projectors
    write(lun,fmt='(2i4,20x,"# Lmax for projectors, no of proj")') pseudo(i_species)%lmax,pseudo(i_species)%n_pjnl
    call io_close(lun)
    return
  end subroutine write_header

  subroutine write_paos(i_species)

    use datatypes
    use numbers, ONLY: two, zero
    use species_module, ONLY: n_species
    use input_module, ONLY: io_assign, io_close
    use mesh, ONLY: nmesh_reg, rmesh_reg
    use pseudo_atom_info, ONLY: paos, val
    use pseudo_tm_info, ONLY: pseudo
    use periodic_table, ONLY: pte
    
    implicit none

    integer :: i_species
    
    
    integer :: lun, i, j, ell, zeta, i_shell, en, is_pol
    real(double) :: occ
    character(len=80) :: filename
    
    ! Open file
    call io_assign(lun)
    filename = trim(pte(pseudo(i_species)%z))//"CQ.ion"
    open(unit=lun, file=filename,position="append")
    ! PAOs
    write(lun,fmt='("# PAOs:_______________")')
    do i_shell=1,paos%n_shells
       is_pol = 0
       ell = paos%l(i_shell)
       en = paos%n(i_shell)
       if(paos%flag_perturb_polarise.AND.i_shell==paos%n_shells) then
          !ell = ell + 1
          !if(en<3) en = en + 1
          is_pol = 1
       else if(i_shell>val%n_occ) then
          is_pol = 1
       end if
       do zeta = 1,paos%nzeta(i_shell)
          occ = zero
          if(i_shell<=val%n_occ.AND.zeta==1) then
             occ = val%occ(i_shell)
          end if
          write(lun,fmt='(4i3,f10.6,"  #orbital l, n, z, is_polarized, population")') &
               ell,en,zeta,is_pol,occ
          write(lun,fmt='(i4,2f21.16)') paos%psi_reg(zeta,i_shell)%n,paos%psi_reg(zeta,i_shell)%delta, &
               paos%cutoff(zeta,i_shell)
          do i=1,paos%psi_reg(zeta,i_shell)%n
             write(lun,fmt='(2f16.12)') paos%psi_reg(zeta,i_shell)%x(i), paos%psi_reg(zeta,i_shell)%f(i)
          end do
       end do
    end do
    call io_close(lun)
    return
  end subroutine write_paos

  subroutine write_pseudopotential(i_species)

    use datatypes
    use numbers, ONLY: two, fourpi
    use species_module, ONLY: n_species
    use input_module, ONLY: io_assign, io_close
    use pseudo_tm_info, ONLY: alloc_pseudo_info, pseudo, rad_alloc
    use global_module, ONLY: flag_pcc_global
    use periodic_table, ONLY: pte
    
    implicit none

    integer :: i_species

    integer :: lun, i, j
    character(len=80) :: filename
    
    ! Open file
    call io_assign(lun)
    filename = trim(pte(pseudo(i_species)%z))//"CQ.ion"
    open(unit=lun, file=filename,position="append")
    ! KB projectors 
    write(lun,fmt='("# KBs:_______________")')
    do i=1,pseudo(i_species)%n_pjnl
       write(lun,fmt='(2i3,f21.16,"  #kb l, n (seq), energy in Ry")') &
            pseudo(i_species)%pjnl_l(i), pseudo(i_species)%pjnl_n(i), two*pseudo(i_species)%pjnl_ekb(i)
       write(lun,fmt='(i4,2f21.16)') pseudo(i_species)%pjnl(i)%n,pseudo(i_species)%pjnl(i)%delta,pseudo(i_species)%pjnl(i)%cutoff
       do j = 1, pseudo(i_species)%pjnl(i)%n
          write(lun,fmt='(2f17.11)') real(j-1,double)*pseudo(i_species)%pjnl(i)%delta,pseudo(i_species)%pjnl(i)%f(j)
       end do
    end do
    ! VNA
    write(lun,fmt='("# Vna:_______________")')
    write(lun,fmt='(i4,2f16.12,"  # npts, delta, cutoff")') &
         pseudo(i_species)%vna%n, pseudo(i_species)%vna%delta, pseudo(i_species)%vna%cutoff
    do j=1,pseudo(i_species)%vna%n
       write(lun,fmt='(2f17.11)') real(j-1,double)*pseudo(i_species)%vna%delta,pseudo(i_species)%vna%f(j)
    end do
    ! Local charge
    write(lun,fmt='("# Vlocal:_______________________")')
    write(lun,fmt='(i4,2f16.12,"  # npts, delta, cutoff")') &
         pseudo(i_species)%vlocal%n, pseudo(i_species)%vlocal%delta, pseudo(i_species)%vlocal%cutoff
    do j=1,pseudo(i_species)%vlocal%n
       write(lun,fmt='(2f17.11)') real(j-1,double)*pseudo(i_species)%vlocal%delta,pseudo(i_species)%vlocal%f(j)
    end do
    ! Partial Core Correction
    if(pseudo(i_species)%flag_pcc) then
       write(lun,fmt='("# Core:__________________________")')       
       write(lun,fmt='(i4,2f16.12,"  # npts, delta, cutoff")') &
            pseudo(i_species)%chpcc%n, pseudo(i_species)%chpcc%delta, pseudo(i_species)%chpcc%cutoff
       do j=1,pseudo(i_species)%chpcc%n
          write(lun,fmt='(2f17.11)') real(j-1,double)*pseudo(i_species)%chpcc%delta,pseudo(i_species)%chpcc%f(j)/fourpi
       end do
    end if
    call io_close(lun)
    return
  end subroutine write_pseudopotential

  subroutine write_pao_plot(z,r,pao,n_mesh,en,ell,zeta)

    use datatypes
    use input_module, ONLY: io_assign, io_close
    use pseudo_tm_info, ONLY: pseudo
    use periodic_table, ONLY: pte
    
    implicit none

    ! Passed variables
    integer :: z, n_mesh, ell, en, zeta
    real(double), dimension(n_mesh) :: r, pao

    ! Local variables
    character(len=80) :: filename
    character(len=10) :: digitstr = "0123456789"
    integer :: lun,i

    filename = trim(pte(z))//"PAO_n_"//digitstr(en+1:en+1)//"_l_"//digitstr(ell+1:ell+1)//"_zeta_"//digitstr(zeta+1:zeta+1)//".dat"
    call io_assign(lun)
    open(unit=lun, file=filename)
    do i=1,n_mesh
       write(lun,fmt='(2f18.10)') r(i),pao(i)
    end do
    call io_close(lun)
    return
  end subroutine write_pao_plot

  subroutine write_banner

    use datestamp, ONLY: datestr, commentver

    implicit none

    character(len=10) :: today, the_time

    write(*,fmt='(/"CONQUEST PAO generation and ion file creation"/)')
    write(*,fmt='("D. R. Bowler (UCL) and T. Miyazaki (NIMS)")')
    call date_and_time(today, the_time)
    write(*,fmt='(/4x,"This job was run on ",a4,"/",a2,"/",a2," at ",a2,":",a2,/)') &
         today(1:4), today(5:6), today(7:8), the_time(1:2), the_time(3:4)
    write(*,&
          '(/4x,"Code compiled on: ",a,/10x,"Version comment: ",/6x,a//)') &
         datestr, commentver
  end subroutine write_banner

end module write
