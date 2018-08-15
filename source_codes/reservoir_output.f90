      subroutine reservoir_output(j)
      
      use time_module
      use basin_module
      use reservoir_module
      use hydrograph_module
      
      implicit none
      
      integer, intent (in) :: j   !                |
      integer :: iob              !                |
      real :: const               !                |
      
      iob = sp_ob1%res + j - 1

!!!!! daily print
         if (pco%day_print == "y" .and. pco%int_day_cur == pco%int_day) then
          if (pco%res%d == "y") then
            write (2540,100) time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_d(j)
             if (pco%csvout == "y") then
               write (2544,'(*(G0.3,:","))') time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_d(j) 
             end if
          end if 
        end if 
                                                    
        res_m(j) = res_m(j) + res_d(j)

!!!!! monthly print
        if (time%end_mo == 1) then
          const = float (ndays(time%mo + 1) - ndays(time%mo))
          res_m(j)%vol = res_m(j)%vol / const
          res_m(j)%area_ha = res_m(j)%area_ha / const
          res_y(j) = res_y(j) + res_m(j)
          if (pco%res%m == "y") then
            write (2541,100) time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_m(j)
              if (pco%csvout == "y") then
                write (2545,'(*(G0.3,:","))') time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_m(j) 
              end if 
          end if
          res_m(j) = resmz
        end if

!!!!! yearly print
       if (time%end_yr == 1) then
          res_y(j)%vol = res_y(j)%vol / 12.
          res_y(j)%area_ha = res_y(j)%area_ha / 12.
          res_a(j) = res_a(j) + res_y(j)
          if (pco%res%y == "y") then
            write (2542,100) time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_y(j)
              if (pco%csvout == "y") then
                write (2546,'(*(G0.3,:","))') time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_y(j)
              end if
          end if
          res_y(j) = resmz
       end if

!!!!! average annual print
        if (time%end_sim == 1 .and. pco%res%a == "y") then
          res_a(j) = res_a(j) / time%yrs_prt
          write (2543,100) time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_a(j)
          if (pco%csvout == "y") then
            write (2547,'(*(G0.3,:","))')time%day, time%mo, time%day_mo, time%yrc, j, ob(iob)%gis_id, ob(iob)%name, res_a(j)
          end if 
          res_a(j) = resmz
        end if
        
      return
        
100   format (4i6,2i8,2x,a,e10.3,e12.3,44e10.3)
       
      end subroutine reservoir_output