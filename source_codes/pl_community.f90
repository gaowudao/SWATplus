      subroutine pl_community

!!    ~ ~ ~ PURPOSE ~ ~ ~
!!    this subroutine predicts daily potential growth of total plant
!!    biomass and roots and calculates leaf area index. Incorporates
!!    residue for tillage functions and decays residue on ground
!!    surface. Adjusts daily dry matter based on water stress.

!!    ~ ~ ~ INCOMING VARIABLES ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    phubase(:)  |heat units    |base zero total heat units (used when no
!!                               |land cover is growing)
!!    phutot(:)   |heat units    |total potential heat units for year (used
!!                               |when no crop is growing)
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ OUTGOING VARIABLES ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    phubase(:)  |heat units    |base zero total heat units (used when no
!!                               |land cover is growing)
!!    sol_cov(:)  |kg/ha         |amount of residue on soil surface
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ LOCAL DEFINITIONS ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ SUBROUTINES/FUNCTIONS CALLED ~ ~ ~
!!    Intrinsic: Max
!!    SWAT: operatn, swu, grow

!!    ~ ~ ~ ~ ~ ~ END SPECIFICATIONS ~ ~ ~ ~ ~ ~

      use hru_module, only : ep_max, epmax, hru_ra, htfac, ihru, ipl, par, sol_cov, sum_no3,  &
         sum_solp, tmpav, translt, uapd, uapd_tot, uno3d, uno3d_tot
      use soil_module
      use plant_module
      use plant_data_module
      use organic_mineral_mass_module
      use time_module
      
      implicit none      

      integer :: j              !none          |HRU number
      integer :: idp            !              | 
      integer :: npl_gro        !              | 
      integer :: ip 
      integer :: jpl            !none          |counter
      real :: x1                !              |
      real :: sum               !              |
      real :: sumf              !              |
      real :: sumle             !              |
      real :: fi                !              |
      real :: delg              !              |
      integer :: nly            !none          |counter
      

      j = ihru  
      par = 0.

      !! sum vegetative biomass for each plant
      sol_cov(j) = 0.
      do ipl = 1, pcom(j)%npl
        sol_cov(j) = sol_cov(j) + .8 * pcom(j)%plm(ipl)%mass
      end do
      !! add surface residue to cover
      sol_cov(j) = sol_cov(j) + rsd1(j)%tot_com%m

      !! calc total lai for plant community
      pcom(j)%lai_sum = 0.
      do ipl = 1, pcom(j)%npl
        pcom(j)%lai_sum = pcom(j)%lai_sum + pcom(j)%plg(ipl)%lai
      end do
      !! calc max water uptake for each plant
      do ipl = 1, pcom(j)%npl
        if (pcom(j)%lai_sum > 1.e-6) then
          epmax(ipl) = ep_max * pcom(j)%plg(ipl)%lai / pcom(j)%lai_sum
        else
          epmax(ipl) = 0.
        end if
      end do

      !! calc total root mass for plant community
      pcom(j)%root_com%mass = 0.
      do ipl = 1, pcom(j)%npl
        pcom(j)%root_com%mass = amax1 (pcom(j)%root_com%mass, pcom(j)%root(ipl)%mass)
      end do
      
      !! calc max height for penman pet equation
      pcom(j)%cht_mx = 0.
      do ipl = 1, pcom(j)%npl
        pcom(j)%cht_mx = amax1 (pcom(j)%cht_mx, pcom(j)%plg(ipl)%cht)
      end do
      
      !! calc total biomass for plant community
      pcom(j)%tot_com%mass = 0.
      do ipl = 1, pcom(j)%npl
        pcom(j)%tot_com%mass = amax1 (pcom(j)%tot_com%mass, pcom(j)%plm(ipl)%mass)
      end do
      
      npl_gro = 0
      do ipl = 1, pcom(j)%npl
        if (pcom(j)%plcur(ipl)%gro == "y") then
          call pl_waterup
          npl_gro = npl_gro + 1
          ip = ipl  !used for only one plant growing
        end if
      end do
 
      !! calculate photosynthetically active radiation during growth period
      if (npl_gro == 1) then
        !! calculate photosynthetically active radiation for one plant
        if (pcom(j)%plcur(ip)%idorm == "n" .and. pcom(j)%plcur(ip)%gro        & 
                                                              == "y")then
          idp = pcom(j)%plcur(ip)%idplt
          pl_db => pldb(idp)
          par(ip) = .5 * hru_ra(j) * (1. - Exp(-pldb(idp)%ext_coef *        &    
                (pcom(j)%plg(ip)%lai + .05)))
        end if
      else if (npl_gro > 1) then
        !! calculate photosynthetically active radiation for multiple plants
        if (pcom(j)%lai_sum > 1.e-6) then
          translt = 0.
          do ipl = 1, pcom(j)%npl
            do jpl = 1, pcom(j)%npl
              x1 = pcom(j)%plg(jpl)%cht - .5 * pcom(j)%plg(ipl)%cht
              if (x1 > 0.) then
                idp = pcom(j)%plcur(ipl)%idplt
                pl_db => pldb(idp)
                translt(ipl) = translt(ipl) + x1 / (pcom(j)%plg(ipl)%cht + 1.e-6) *   & 
                         pcom(j)%plg(ipl)%lai * (-pldb(idp)%ext_coef)
              end if
            end do
          end do
          sum = 0.
          do ipl = 1,pcom(j)%npl
            translt(ipl) = exp(translt(ipl))
            sum = sum + translt(ipl)
          end do
          sumf = 0.
          sumle = 0.
          do ipl = 1, pcom(j)%npl
            idp = pcom(j)%plcur(ipl)%idplt
            translt(ipl) = translt(ipl) / sum
            x1 = pcom(j)%plg(ipl)%lai * pldb(idp)%ext_coef
            sumle = sumle + x1
            sumf = sumf + (1. - exp(-x1)) * translt(ipl)
          end do
          fi = 1. - exp(-sumle)
          do ipl = 1, pcom(j)%npl
            idp = pcom(j)%plcur(ipl)%idplt
            if (sumf > 0.) then
              htfac(ipl) = (1. - exp(-pldb(idp)%ext_coef *                  &             
                          pcom(j)%plg(ipl)%lai)) * translt(ipl) / sumf
            else
              htfac(ipl) = 1.
            end if
            htfac(ipl) = fi * htfac(ipl)
            htfac(ipl) = 1.
            par(ipl) = .5 * htfac(ipl) * hru_ra(j) * (1. -                  &              
              Exp(-pldb(idp)%ext_coef * (pcom(j)%plg(ipl)%lai + .05)))
          end do  
        end if
      end if
      
      uno3d(ipl) = 0.
      uno3d_tot = 0.
      uapd(ipl) = 0.
      uapd_tot = 0.
      do ipl = 1, pcom(j)%npl
        idp = pcom(j)%plcur(ipl)%idplt
        if (pcom(j)%plcur(ipl)%idorm == 'n'.and.pcom(j)%plcur(ipl)%gro=="y")    &
                                                                   then
        !! update accumulated heat units for the plant
        delg = 0.
        if (pcom(j)%plcur(ipl)%phumat > 0.1) then
          delg = (tmpav(j) - pldb(idp)%t_base) / pcom(j)%plcur(ipl)%phumat
        end if
        if (delg < 0.) delg = 0.
        pcom(j)%plcur(ipl)%phuacc = pcom(j)%plcur(ipl)%phuacc + delg  
        call pl_nupd
        call pl_pupd
        uno3d_tot = uno3d_tot + uno3d(ipl)
        uapd_tot = uapd_tot + uapd(ipl)
        end if
      end do
      sum_no3 = 0.
      sum_solp = 0.
      do nly = 1, soil(j)%nly
        sum_no3 = sum_no3 + soil1(j)%mn(nly)%no3
        sum_solp = sum_solp + soil1(j)%mp(nly)%lab
      end do

      return
      
      end subroutine pl_community