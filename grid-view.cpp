#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <dune/copasi/gmsh_reader.hh>
#include <dune/copasi/model_diffusion_reaction.cc>
#include <dune/copasi/model_diffusion_reaction.hh>
#include <dune/copasi/model_multidomain_diffusion_reaction.cc>
#include <dune/copasi/model_multidomain_diffusion_reaction.hh>

#include <dune/grid/io/file/gmshreader.hh>
#include <dune/grid/multidomaingrid.hh>

#include <dune/logging/logging.hh>

#include <dune/common/exceptions.hh>
#include <dune/common/parallel/mpihelper.hh>
#include <dune/common/parametertree.hh>
#include <dune/common/parametertreeparser.hh>

#include <dune/grid/io/file/printgrid.hh>

#include <QImage>
#include <QPainter>

#include <iostream>

constexpr int dim = 2;
using HostGrid = Dune::UGGrid<dim>;
using MDGTraits = Dune::mdgrid::DynamicSubDomainCountTraits<dim, 1>;
using Grid = Dune::mdgrid::MultiDomainGrid<HostGrid, MDGTraits>;

QImage getConcImage(
    Dune::Copasi::ModelMultiDomainDiffusionReaction<Grid>& model,
    const Grid* grid, const Dune::ParameterTree& config,
    const QSize& imageSize = QSize(2000, 2000)) {
  QImage img(imageSize, QImage::Format_ARGB32);
  img.fill(0);
  QPainter p(&img);
  p.setRenderHint(QPainter::Antialiasing);
  std::vector<QColor> cols{QColor(235, 235, 255, 255), QColor(0, 66, 99, 255)};
  QBrush fillBrush(cols[1]);
  p.setPen(QPen(Qt::black, 1));
  const auto& compartments = config.sub("model.compartments").getValueKeys();
  for (const auto& compartment : compartments) {
    std::size_t iDomain =
        config.sub("model.compartments").get<std::size_t>(compartment);
    fillBrush.setColor(cols.at(iDomain));
    p.setBrush(fillBrush);
    const auto& gridview =
        grid->subDomain(static_cast<int>(iDomain)).leafGridView();
    std::cout << "COMP: " << compartment << std::endl;
    // NB: species index is position in *sorted* list of species names
    // so make copy of list from ini file and sort it
    auto species_names =
        config.sub("model." + compartments[iDomain] + ".initial")
            .getValueKeys();
    std::sort(species_names.begin(), species_names.end());
    double scaleFactor = 10.0;
    for (std::size_t iSpecies = 0; iSpecies < species_names.size();
         ++iSpecies) {
      std::cout << "SPECIES: " << species_names[iSpecies] << std::endl;
      auto gf = model.get_grid_function(model.states(), iDomain, iSpecies);
      using GF = decltype(gf);
      using Range = typename GF::Traits::RangeType;
      using Domain = typename GF::Traits::DomainType;
      Range result;
      for (const auto e : elements(gridview)) {
        double av = 0;
        const auto& geo = e.geometry();
        assert(geo.type().isTriangle());

        QPointF c0(geo.corner(0)[0], geo.corner(0)[1]);
        QPainterPath path(c0 * scaleFactor);
        gf.evaluate(e, {0, 0}, result);
        av += result;

        QPointF c1(geo.corner(1)[0], geo.corner(1)[1]);
        path.lineTo(c1 * scaleFactor);
        gf.evaluate(e, {1, 0}, result);
        av += result;

        QPointF c2(geo.corner(2)[0], geo.corner(2)[1]);
        path.lineTo(c2 * scaleFactor);
        gf.evaluate(e, {0, 1}, result);
        av += result;

        path.lineTo(c0 * scaleFactor);
        av /= 3.0;
        // p.fillPath(path, fillBrush);
        p.drawPath(path);
      }
    }
  }
  p.end();
  return img.mirrored(false, true);
}

int main() {
  // initialize model
  auto& mpi_helper = Dune::MPIHelper::instance(0, nullptr);
  auto comm = mpi_helper.getCollectiveCommunication();
  Dune::ParameterTree config;
  Dune::ParameterTreeParser ptreeparser;
  // NB: can pass istream instead of file here
  ptreeparser.readINITree("../liver.ini", config);
  Dune::Logging::Logging::init(comm, config.sub("logging"));
  // NB: msh file needs to be file for gmshreader
  auto [grid_ptr, host_grid_ptr] =
      Dune::Copasi::GmshReader<Grid>::read("../grid.msh", config);
  grid_ptr->globalRefine(0);
  Dune::Copasi::ModelMultiDomainDiffusionReaction<Grid> model(
      grid_ptr, config.sub("model"));

  // run model
  // model.run();

  auto img = getConcImage(model, grid_ptr.get(), config);
  img.save("conc.png");

  return 0;

  // zero-th order:
  //  - average concentrations over the three corners to get av conc of triangle

  // first order: linear function along each edge.
  // given c at each of three corners 0,1,2:
  //   - construct two unit vectors: 0->1 and 0->2
  //   - point x

  // higher order: more points than corners, use quadrature points to iterate
  // over them
}
